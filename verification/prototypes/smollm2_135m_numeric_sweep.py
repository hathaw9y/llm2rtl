"""Small, reproducible numeric sensitivity sweep for the proposed GEMM policy."""

import json
import torch
from transformers import AutoModelForCausalLM, AutoTokenizer

from smollm2_135m_isa_feasibility import CHECKPOINT, DDR, Machine, build_block, compare


def main():
    torch.set_num_threads(4)
    model = AutoModelForCausalLM.from_pretrained(
        str(CHECKPOINT), local_files_only=True, dtype=torch.bfloat16,
        attn_implementation="eager").eval()
    tokenizer = AutoTokenizer.from_pretrained(str(CHECKPOINT), local_files_only=True)
    english = ("The little robot looked at the night sky and wondered why the stars "
               "seemed to move so slowly. It wrote a careful note in its journal. ")
    korean = ("작은 로봇은 밤하늘을 바라보며 별이 왜 천천히 움직이는지 생각했다. "
              "그리고 자신의 관찰을 일기에 자세히 적었다. ")
    rng = torch.Generator().manual_seed(20260929)
    cases = {
        "arithmetic_token_ids": [(i * 17 + 11) % 49152 for i in range(33)],
        "random_token_ids": torch.randint(0, 49152, (33,), generator=rng).tolist(),
        "repeated_token": [42] * 33,
        "english_text": tokenizer.encode(english * 8, add_special_tokens=False)[:33],
        "korean_text": tokenizer.encode(korean * 8, add_special_tokens=False)[:33],
    }
    ddr = DDR(model, [])
    results = []
    with torch.inference_mode():
        for case_name, tokens in cases.items():
            assert len(tokens) == 33
            ddr.kv.clear()
            machine = Machine(ddr, gemm_mode="fp32_accumulate_bf16_round")
            cache = None
            for start, size in ((0, 32), (32, 1)):
                ids = tokens[start:start + size]
                candidate = machine.run(build_block(ids, start, True)).float()
                reference = model(torch.tensor([ids]), past_key_values=cache,
                                  use_cache=True, logits_to_keep=1)
                cache = reference.past_key_values
                oracle = reference.logits[0].float()
                stats = compare(f"{case_name}_{start + size}", candidate, oracle)
                ref_top = torch.topk(oracle.reshape(-1), 2)
                cand_top = torch.topk(candidate.reshape(-1), 2)
                stats.update({
                    "reference_top1_id": int(torch.argmax(oracle)),
                    "candidate_top1_id": int(torch.argmax(candidate)),
                    "reference_margin": float(ref_top.values[0] - ref_top.values[1]),
                    "candidate_margin": float(cand_top.values[0] - cand_top.values[1]),
                    "candidate_top_ties": int((candidate == candidate.max()).sum()),
                    "top1_equal": bool(torch.argmax(candidate) == torch.argmax(oracle)),
                })
                results.append(stats)
    print(json.dumps({"gemm_mode": "FP32 F.linear on BF16 operands then BF16 cast",
                      "case_count": len(cases), "results": results}, indent=2))


if __name__ == "__main__":
    main()
