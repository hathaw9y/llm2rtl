#!/usr/bin/env python3
"""Host tokenizer and greedy token selector for the PL ISA board runtime."""
from __future__ import annotations
import argparse
import pathlib
import struct
import sys
import time
import zlib

import serial
from transformers import AutoTokenizer

VOCAB = 49152
LOGIT_BYTES = VOCAB * 2
HERE = pathlib.Path(__file__).resolve().parent


class Board:
    def __init__(self, port: str, baud: int):
        self.serial = serial.Serial(port, baudrate=baud, timeout=1,
                                    write_timeout=15)
        self.last_compute_us = 0
        self.last_wall_s = 0.0

    def close(self):
        self.serial.close()

    def line(self, deadline: float) -> str:
        while time.monotonic() < deadline:
            data = self.serial.read_until(b'\n', size=1024)
            if not data or not data.endswith(b'\n'):
                continue
            line = data.decode('ascii', errors='replace').strip()
            if line:
                if line.startswith('ERROR '):
                    raise RuntimeError(f'Board error: {line}')
                return line
        raise TimeoutError('Timed out waiting for UART line')

    def ready(self, timeout: float):
        deadline = time.monotonic() + timeout
        self.serial.reset_input_buffer()
        while time.monotonic() < deadline:
            self.serial.write(b'RESET\n')
            self.serial.flush()
            attempt = min(deadline, time.monotonic() + 5)
            try:
                while time.monotonic() < attempt:
                    line = self.line(attempt)
                    if line == 'READY 1024 32 49152':
                        return
                    print(f'[board] {line}', file=sys.stderr)
            except TimeoutError:
                pass
        raise TimeoutError('Board did not report READY; check SD load and UART port')

    def exact(self, count: int, timeout: float) -> bytes:
        chunks = []
        received = 0
        deadline = time.monotonic() + timeout
        while received < count and time.monotonic() < deadline:
            data = self.serial.read(min(4096, count - received))
            if data:
                chunks.append(data)
                received += len(data)
        if received != count:
            raise TimeoutError(f'UART logits received {received}/{count} bytes')
        return b''.join(chunks)

    def block(self, start: int, token_ids: list[int], logits: bool,
              timeout: float) -> bytes | None:
        assert 1 <= len(token_ids) <= 32
        assert 0 <= start and start + len(token_ids) <= 1024
        assert all(0 <= token < VOCAB for token in token_ids)
        command = 'B ' + ' '.join(map(str, (start, len(token_ids), int(logits),
                                           *token_ids))) + '\n'
        began = time.monotonic()
        self.serial.write(command.encode('ascii'))
        self.serial.flush()
        deadline = time.monotonic() + timeout
        expected_done = f'BLOCK_DONE {start} {start + len(token_ids)} '
        while True:
            line = self.line(deadline)
            if line.startswith(expected_done):
                fields = line.split()
                if len(fields) != 5:
                    raise RuntimeError(f'Bad block completion: {line}')
                self.last_compute_us = int(fields[4])
                break
            print(f'[board] {line}', file=sys.stderr)
        if not logits:
            self.last_wall_s = time.monotonic() - began
            return None
        while True:
            line = self.line(deadline)
            if line.startswith('LOGITS '):
                fields = line.split()
                if len(fields) != 3 or int(fields[1]) != start + len(token_ids) - 1 \
                   or int(fields[2]) != LOGIT_BYTES:
                    raise RuntimeError(f'Bad logits header: {line}')
                break
            print(f'[board] {line}', file=sys.stderr)
        values = self.exact(LOGIT_BYTES, timeout)
        checksum = None
        while checksum is None:
            line = self.line(time.monotonic() + 10)
            if line.startswith('LOGITS_END '):
                checksum = int(line.split()[1], 16)
        actual = zlib.crc32(values)
        if checksum != actual:
            raise RuntimeError(f'UART CRC mismatch {actual:08x} != {checksum:08x}')
        self.last_wall_s = time.monotonic() - began
        return values

    def rate(self, rows: int) -> str:
        if self.last_compute_us == 0 or self.last_wall_s == 0:
            return 'rate unavailable'
        return (f'board={rows * 1e6 / self.last_compute_us:.4f} tok/s '
                f'UART_included={rows / self.last_wall_s:.4f} tok/s '
                f'board_us={self.last_compute_us} '
                f'roundtrip_s={self.last_wall_s:.3f}')


def greedy(logits: bytes) -> tuple[int, float, int, float]:
    if len(logits) != LOGIT_BYTES:
        raise ValueError('wrong logits size')
    best = (-1, float('-inf'))
    second = (-1, float('-inf'))
    for index, (bits,) in enumerate(struct.iter_unpack('<H', logits)):
        value = struct.unpack('<f', struct.pack('<I', bits << 16))[0]
        if value != value:
            raise ValueError(f'NaN logit at token {index}')
        if value > best[1]:
            second = best
            best = (index, value)
        elif value > second[1]:
            second = (index, value)
    return best[0], best[1], second[0], second[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--port', required=True, help='PS UART, e.g. /dev/ttyUSB1')
    parser.add_argument('--baud', type=int, default=115200)
    parser.add_argument('--prompt', help='Text to continue; asked interactively if absent')
    parser.add_argument('--qa', action='store_true',
                        help='Wrap text as Question: ...\\nAnswer:')
    parser.add_argument('--max-new-tokens', type=int, default=32)
    parser.add_argument('--board-timeout', type=float, default=900)
    args = parser.parse_args()
    if args.max_new_tokens < 1:
        parser.error('--max-new-tokens must be positive')
    prompt = args.prompt if args.prompt is not None else input('Prompt> ')
    if args.qa:
        prompt = f'Question: {prompt}\nAnswer:'
    tokenizer = AutoTokenizer.from_pretrained(str(HERE / 'tokenizer'),
                                               local_files_only=True)
    token_ids = tokenizer.encode(prompt, add_special_tokens=False)
    if not token_ids:
        parser.error('Prompt produced no tokens')
    if len(token_ids) + args.max_new_tokens > 1024:
        parser.error(f'Prompt uses {len(token_ids)} tokens; prompt plus output '
                     'must fit 1024 tokens')
    print(f'[host] prompt tokens={len(token_ids)}, max new={args.max_new_tokens}',
          file=sys.stderr)
    board = Board(args.port, args.baud)
    try:
        board.ready(args.board_timeout)
        generation_start = time.monotonic()
        prefill_board_s = 0.0
        prefill_wall_s = 0.0
        logits = None
        for start in range(0, len(token_ids), 32):
            block = token_ids[start:start + 32]
            final = start + len(block) == len(token_ids)
            logits = board.block(start, block, final, args.board_timeout)
            prefill_board_s += board.last_compute_us / 1e6
            prefill_wall_s += board.last_wall_s
            print(f'[host] prefill {start + len(block)}/{len(token_ids)} '
                  f'{board.rate(len(block))}',
                  file=sys.stderr)
        print(f'[host] TTFT_including_logits_UART='
              f'{time.monotonic() - generation_start:.3f}s '
              f'prefill_board={len(token_ids) / prefill_board_s:.4f} tok/s '
              f'prefill_UART_included={len(token_ids) / prefill_wall_s:.4f} tok/s',
              file=sys.stderr)
        generated: list[int] = []
        decode_board_s = 0.0
        decode_wall_s = 0.0
        decode_blocks = 0
        print('Answer: ', end='', flush=True)
        for step in range(args.max_new_tokens):
            assert logits is not None
            token, score, runner, runner_score = greedy(logits)
            print(f'\n[host] step={step} token={token} logit={score:.4f} '
                  f'runner={runner}:{runner_score:.4f}', file=sys.stderr)
            if token == tokenizer.eos_token_id:
                break
            generated.append(token)
            print(tokenizer.decode([token], skip_special_tokens=True),
                  end='', flush=True)
            if step + 1 == args.max_new_tokens:
                break
            position = len(token_ids) + len(generated) - 1
            logits = board.block(position, [token], True, args.board_timeout)
            decode_board_s += board.last_compute_us / 1e6
            decode_wall_s += board.last_wall_s
            decode_blocks += 1
            print(f'[host] decode {board.rate(1)}', file=sys.stderr)
        print()
        if decode_blocks:
            print(f'[host] decode aggregate blocks={decode_blocks} '
                  f'board={decode_blocks / decode_board_s:.4f} tok/s '
                  f'UART_included={decode_blocks / decode_wall_s:.4f} tok/s',
                  file=sys.stderr)
        print(f'[host] generated IDs: {generated}', file=sys.stderr)
        print(f'[host] decoded text: '
              f'{tokenizer.decode(generated, skip_special_tokens=True)}',
              file=sys.stderr)
    finally:
        board.close()


if __name__ == '__main__':
    main()
