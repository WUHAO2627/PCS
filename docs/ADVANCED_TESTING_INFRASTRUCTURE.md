# Advanced Testing Notes

This note summarizes the extra scenarios used to stress the integrated model.

## Island Load Mix

The island-load path combines multiple branches in `project/integration/build_integrated_system_model.m`:

- base RL branch (always on)
- delayed step RL branch
- nonlinear rectifier-like branch

Use this setup to check transient voltage regulation and control robustness under harmonic load current.

## How To Run

From project root:

```matlab
test_advanced_models
```

The test script rebuilds the integrated model and runs a short simulation.

## Expected Checks

- DC bus ripple stays bounded after the load step.
- AC current distortion increases when nonlinear branch is active.
- Controller states remain stable (no runaway integrator behavior).

## Notes

- If switching-level AFE scripts are not present in current branch, keep the test focused on the integrated model path.
- Keep this file short; implementation details belong in code comments and model documentation.

