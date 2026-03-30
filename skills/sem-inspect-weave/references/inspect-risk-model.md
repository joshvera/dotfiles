# inspect Risk Model (Why inspect after sem)

`sem` establishes structural truth: what entities changed.

`inspect` is the prioritization layer: among the changed entities, which deserve careful review?

It does this by combining:

- change classification (text/syntax/functional)
- blast radius (transitive impact)
- dependents count
- public API exposure
- change type

Use inspect to decide review order, not to replace sem.
