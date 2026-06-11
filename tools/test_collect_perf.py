import unittest

from collect_perf import parse_perf_line


class CollectPerfTest(unittest.TestCase):
    def test_parse_record(self) -> None:
        record = parse_perf_line(
            "WARPFORGE_PERF workload=gemm policy=SCHED_ROUND_ROBIN "
            "seed=17 cycles=40 issued=4 scalar=0 tensor=1 prefetch=1 "
            "scheduler_stall=1 scoreboard_stall=0 tile_wait=2 "
            "tensor_wait=0 prefetch_stall=0 tensor_busy=4 "
            "tensor_accepted=1 tensor_completed=1 bank_conflicts=0 "
            "prefetch_requests=1 prefetch_stalls=0 completed_warps=1 "
            "illegal=0"
        )
        self.assertIsNotNone(record)
        self.assertEqual(record["workload"], "gemm")
        self.assertEqual(record["tensor_utilization_percent"], "10.000")

    def test_non_record(self) -> None:
        self.assertIsNone(parse_perf_line("ordinary simulator output"))


if __name__ == "__main__":
    unittest.main()
