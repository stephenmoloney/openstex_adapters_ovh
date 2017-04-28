# Changelog

## v0.3.6

[changes]
- Bump dependency versions

## v0.3.4

[bug fix]
- Remove Og logs - no longer a dependency.

## v0.3.3

[bug fix]
- Incorrect regions. OVH regions changed recently - now fetch them from the identity token if left
absent in the `config.exs` as a default.


## v0.3.2

[bug fix]
- `no match of right hand side value: %{ "description" => "app description"}`. No match due
to fixing on "ex_ovh".


## v0.3.1

[security fix]
- Remove any potential dependency on `Og` through older `ex_ovh` packages. A potential security issue exists with the use of
[Code.eval_string/3](https://github.com/elixir-lang/elixir/commit/f1daca5be78e6a466745ba2cdc66d9787c3cf47f#diff-da151e1c1d9b535259a2385407272c9eR107).
in versions of `Og` less than `1.0.0`. Fixing ex_ovh to `v0.3.2` or above solves this security issue.

[changes]
- improve `README.md`
- lock dependency of `v0.3.1` to `v0.3.2` of ex_ovh to ensure older versions of `exovh` are
excluded.


## v0.3.0

***Security Warning: Version v0.3.0 of openstex_adapters_ovh should not be used as it has a dependency
on `ex_ovh ~> 0.3`. Versions of `ex_ovh` less than `0.3.2` are deprecated and should not be used
due to the inclusion of older releases of the dependency `Og`. Use versions `v0.3.1` or greater
of `openstex_adapters_ovh` instead.***

- initial commit
- working adapter for openstex and ovh
- allows for use of swift functions and all of the OVH api features too.