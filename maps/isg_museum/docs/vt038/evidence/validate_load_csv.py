"""Verify T15 raw samples independently and reproduce the p95 table."""
from collections import Counter
import csv
import math
from pathlib import Path
import sys


def p95(samples):
    return sorted(samples)[math.ceil(.95 * len(samples)) - 1]


def main(path):
    with Path(path).open(encoding='utf-8', newline='') as source:
        rows = list(csv.DictReader(source))
    assert len(rows) == 1100, len(rows)
    aggregate = []
    for burst in range(11):
        batch = [row for row in rows if int(row['burst']) == burst]
        assert len(batch) == 100
        assert all(row['phase'] == ('warmup' if burst == 0 else 'measured') for row in batch)
        assert Counter(row['kind'] for row in batch) == {'new': 50, 'retry': 50}
        assert Counter(row['request_id'] for row in batch) == {f'load-{n:02d}': 2 for n in range(1, 51)}
        assert [int(row['arrival']) for row in batch] == list(range(1, 101))
        assert max(int(row['submitted_usec']) for row in batch) <= min(int(row['service_start_usec']) for row in batch)
        samples = []
        new = set()
        for row in batch:
            n = int(row['request_id'].split('-')[1])
            assert row['status'] == 'WRONG_CODE' and not row['error']
            assert row['alarm_triggered'] == ('true' if n % 3 == 0 else 'false')
            assert (int(row['wrong_attempts_after']), int(row['alarm_count_after'])) == (n % 3, n // 3)
            if row['kind'] == 'new':
                assert n not in new
                new.add(n)
            else:
                assert n in new
            submit, start, end = (int(row[k]) for k in ('submitted_usec', 'service_start_usec', 'finished_usec'))
            assert submit <= start <= end
            assert start - submit == int(row['queue_usec'])
            assert end - start == int(row['service_usec'])
            assert end - submit == int(row['latency_usec']) < 10_000_000
            samples.append(end - submit)
        print(f'burst={burst} p95_usec={p95(samples)} n={len(samples)} max_usec={max(samples)}')
        if burst:
            aggregate.extend(samples)
    assert len(aggregate) == 1000 and p95(aggregate) <= 3_000_000
    print(f'aggregate p95_usec={p95(aggregate)} n={len(aggregate)} max_usec={max(aggregate)}')
    print('CSV verification PASS')


if __name__ == '__main__':
    main(sys.argv[1])
