## Solving For Mean Solve Time
In the proof-of-work solver, we keep hashing an input seed, combined with a random string, until we get a resulting hash with `k` number of leading zeros

Each hex digit can take 16 possible values (0-f)

Every hash is an independent Bernoulli trial, with a success probability of `p = 16^-k`

The number of trials until first success follows a geometric distribution, meaning the mean number of trials for `geometric(p)` is `1/p`

This means we can assume the mean number of attempts is `16^k`, and if we assume we can have 10,000 trials per second, then that means the mean time is `16^k / 10_000` seconds

This means if we have a difficulty of 3 for example (3 leading zeros required for the hash), the mean time for a successful trial is `16^3 / 10_000 = 6.5536` seconds
