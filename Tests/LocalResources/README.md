Run on macOS with Xcode installed:

```sh
Tests/LocalResources/run.sh
```

The runner compiles the actual WebKit coordinator and exercises its resource callbacks. It verifies regular-file loading, rejection of devices, FIFOs, directories, symlinks to devices, and files above the 32 MiB per-resource limit, plus callback suppression after cancellation. Fixtures and build products are temporary and removed afterward. No package downloads are required.
