## Average Solve Times
| Num Leading Zeros (difficulty) | Mean Num of Attempts | Mean Solve Time (seconds) |
| --- | --- | --- |
| 1 | 16 | 0.0014 |
| 2 | 256 | 0.022 |
| 3 | 4,096 | 0.355 |
| 4 | 65,536 | 5.67 |
| 5 | 1,048,576 | 90.8 |
| 6 | 16,777,216 | 1453 (~24.2 mins) |
| 7 | 268,435,456 | 23,245 (~6.46 hrs) |
| 8 | 4,294,967,296 | 372,000 (~4.3 days) |

## Solving For Mean Solve Time
In the proof-of-work solver, we keep hashing an input seed, combined with a random string, until we get a resulting hash with `k` number of leading zeros

Each hex digit can take 16 possible values (0-f)

Every hash is an independent Bernoulli trial, with a success probability of `p = 16^-k`

The number of trials until first success follows a geometric distribution, meaning the mean number of trials for `geometric(p)` is `1/p`

This means we can assume the mean number of attempts is `16^k`, and if we assume we can have 10,000 trials per second, then that means the mean time is `16^k / 10_000` seconds

This means if we have a difficulty of 3 for example (3 leading zeros required for the hash), the mean time for a successful trial is `16^3 / 10_000 = 6.5536` seconds
