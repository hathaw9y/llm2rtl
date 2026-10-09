"""Control-only reference for two-bank weight/scale prefetch.

This schedules typed DMA and GEMM operations. It does not execute tensors,
implement RTL, or model vendor AXI handshakes. Durations are scenario inputs.
"""
from dataclasses import dataclass
from heapq import heappush, heappop


@dataclass(frozen=True)
class Tile:
    epoch: int
    n_start: int
    n_count: int
    k: int

    @property
    def weight_bytes(self):
        return self.n_count * self.k

    @property
    def scale_bytes(self):
        return ((self.n_count + 15) // 16 * 4 + 15) // 16 * 16


class Slot:
    def __init__(self, bank):
        self.bank = bank
        self.state = "FREE"
        self.tile = None
        self.phase = None

    def begin(self, tile):
        if self.state != "FREE":
            raise ValueError("cannot overwrite a reserved weight bank")
        self.tile = tile
        self.state = "FILLING"
        self.phase = "weight"

    def finish_dma(self, epoch, phase, byte_count, error=False):
        if self.state != "FILLING" or self.tile.epoch != epoch or self.phase != phase:
            raise ValueError("unmatched or duplicate DMA completion")
        expected = self.tile.weight_bytes if phase == "weight" else self.tile.scale_bytes
        if byte_count != expected:
            raise ValueError("DMA byte count mismatch")
        if error:
            self.state = "FAULT"
            self.phase = None
        elif phase == "weight":
            self.phase = "scale"
        else:
            self.state = "READY"
            self.phase = None

    def activate(self):
        if self.state != "READY":
            raise ValueError("GEMM requires both weight and scale completion")
        self.state = "ACTIVE"

    def finish_gemm(self, epoch, error=False):
        if self.state != "ACTIVE" or self.tile.epoch != epoch:
            raise ValueError("unmatched or duplicate GEMM completion")
        self.state = "FAULT" if error else "FREE"
        self.tile = None if not error else self.tile


def make_tiles(n, k, n_tile=192, first_epoch=0):
    if not 1 <= n <= 49152 or k not in (576, 1536):
        raise ValueError("unsupported model matrix shape")
    if n_tile not in (64, 128, 192) or first_epoch < 0:
        raise ValueError("invalid residency tile width or epoch")
    return [Tile(first_epoch + i, start, min(n_tile, n - start), k)
            for i, start in enumerate(range(0, n, n_tile))]


def build_isa_program(n, k, n_tile=192, first_epoch=0, fragment_records=15):
    """PS-side logical ISA generator; field packing/DDR bases are not frozen.

    Relative DDR offsets are relocation inputs for DMA only. Both scale and
    weight transfer completion are required before GEMM. END drains each
    fragment, including a prefetch accepted before that fragment boundary.
    """
    if type(fragment_records) is not int or not 1 <= fragment_records <= 15:
        raise ValueError("fragment permits 1..15 work records plus END")
    work = []
    for index, tile in enumerate(make_tiles(n, k, n_tile, first_epoch)):
        bank = (3, 15)[index % 2]
        common = {"bank": bank, "epoch": tile.epoch, "tile_index": index}
        work.extend([
            {"opcode": "BANK_CONFIG", **common, "profile": "weight_INT8",
             "n_count": tile.n_count, "k": k},
            {"opcode": "DMA_LOAD", **common, "phase": "weight",
             "DDR_region": "weight", "DDR_byte_offset": tile.n_start*k,
             "bank_byte_offset": 0, "byte_count": tile.weight_bytes},
            {"opcode": "DMA_LOAD", **common, "phase": "scale",
             "DDR_region": "scale", "DDR_byte_offset": tile.n_start//16*4,
             "bank_byte_offset": 294912, "byte_count": tile.scale_bytes},
            {"opcode": "GEMM_INT8", **common, "source_A_bank": 13,
             "destination_bank": "model_output_bank", "n_start": tile.n_start,
             "n_count": tile.n_count, "k": k},
        ])
    return [work[start:start+fragment_records] + [{"opcode": "END"}]
            for start in range(0, len(work), fragment_records)]


def simulate(n, k, weight_cycles, scale_cycles, gemm_cycles,
             n_tile=192, first_epoch=0, fault=None, fragment_records=None):
    """Drain accepted operations on a matched, memory-quiescent error.

    fault is (tile_index, 'weight'/'scale'/'gemm'). A transport loss that
    cannot provide a quiescent completion requires coordinated reset and
    is outside this reference. GEMM duration includes the final BF16 write.
    DMA duration includes memory endpoint and successful transport status.
    """
    tiles = make_tiles(n, k, n_tile, first_epoch)
    durations = (weight_cycles, scale_cycles, gemm_cycles)
    tables = []
    for value in durations:
        table = list(value) if isinstance(value, (list, tuple)) else [value] * len(tiles)
        if len(table) != len(tiles) or any(type(x) is not int or x <= 0 for x in table):
            raise ValueError("positive integer duration required for every tile")
        tables.append(table)
    if fault is not None and (not 0 <= fault[0] < len(tiles) or
                              fault[1] not in ("weight", "scale", "gemm")):
        raise ValueError("invalid fault scenario")
    slots = [Slot(3), Slot(15)]
    trace, events = [], []
    now = compute_index = 0
    program = build_isa_program(n, k, n_tile, first_epoch,
                                15 if fragment_records is None else fragment_records)
    # None isolates the compute/DMA pipeline. An explicit fragment size models
    # END drains and preserves READY/partial-fill state across the next START.
    records = [r for fragment in program for r in fragment
               if fragment_records is not None or r["opcode"] != "END"]
    fragment_events = []
    pc = 0
    serial = 0
    dma_busy = gemm_busy = failed = False

    def emit(action, slot, phase):
        trace.append({"cycle": now, "action": action, "bank": slot.bank,
                      "epoch": slot.tile.epoch, "phase": phase})

    def schedule(slot, phase, index, cycles):
        nonlocal serial
        serial += 1
        heappush(events, (now + cycles, serial, slot.bank, phase, index))
        emit("accept", slot, phase)

    while True:
        # Examine only the current PS-generated record; never search ahead.
        while not failed and pc < len(records):
            record = records[pc]
            if record["opcode"] == "END":
                if events:
                    break
                fragment_events.append({"cycle": now, "pc": pc,
                                        "bank_states": {s.bank: s.state for s in slots}})
                pc += 1
                continue
            index = record["tile_index"]
            slot = slots[index % 2]
            opcode = record["opcode"]
            if opcode == "BANK_CONFIG":
                if slot.state != "FREE":
                    break
                slot.begin(tiles[index])
            elif opcode == "DMA_LOAD":
                if dma_busy:
                    break
                phase = record["phase"]
                if slot.state != "FILLING" or slot.phase != phase:
                    raise AssertionError("ISA phase mismatch")
                schedule(slot, phase, index, tables[0 if phase == "weight" else 1][index])
                dma_busy = True
            elif opcode == "GEMM_INT8":
                if gemm_busy or slot.state != "READY":
                    break
                if slot.tile != tiles[index] or index != compute_index:
                    raise AssertionError("wrong prefetched tile")
                slot.activate()
                schedule(slot, "gemm", index, tables[2][index])
                gemm_busy = True
            pc += 1
        if not events:
            if not failed and compute_index != len(tiles):
                raise AssertionError("scheduler deadlock")
            break
        now = events[0][0]
        # Collect every completion at this cycle before issuing new work.
        while events and events[0][0] == now:
            _, _, bank, phase, index = heappop(events)
            slot = slots[0 if bank == 3 else 1]
            is_error = fault == (index, phase)
            emit("error" if is_error else "complete", slot, phase)
            if phase == "gemm":
                slot.finish_gemm(tiles[index].epoch, is_error)
                gemm_busy = False
                if not is_error:
                    compute_index += 1
            else:
                byte_count = (tiles[index].weight_bytes if phase == "weight"
                              else tiles[index].scale_bytes)
                slot.finish_dma(tiles[index].epoch, phase, byte_count, is_error)
                dma_busy = False
            failed |= is_error
    return {"status": "error_drained" if failed else "completed",
            "elapsed_cycles": now, "computed_tiles": compute_index,
            "slot_states": {slot.bank: slot.state for slot in slots},
            "trace": trace, "tiles": [tile.__dict__ for tile in tiles],
            "fragment_events": fragment_events,
            "scope": "single-PC logical ISA control scenario; instruction fetch/PS upload costs excluded; END drain modeled only when fragment_records is specified; no tensor, AXI, RTL or hardware proof"}
