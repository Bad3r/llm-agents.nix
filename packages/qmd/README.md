# qmd

Mini CLI search engine for your docs, knowledge bases, meeting notes, whatever. Uses current SOTA approaches while being all local.

## GPU Acceleration

qmd bundles [node-llama-cpp](https://github.com/withcatai/node-llama-cpp) which supports GPU acceleration for embeddings.

### CUDA (NVIDIA)

CUDA is supported on x86_64-linux. Enable it with the `cudaSupport` override:

```nix
qmd.override { cudaSupport = true; }
```

With CUDA 13, the package includes both the selected CUDA runtime and CUDA 12
libraries for node-llama-cpp's bundled fallback binaries. Both are available
during ELF fixup and at runtime. CUDA 12 configurations keep using the fallback
without requiring CUDA 13.

### Vulkan

Vulkan support is enabled by default on Linux for AMD/Intel GPUs. To disable it:

```nix
qmd.override { vulkanSupport = false; }
```

## Links

- [GitHub](https://github.com/tobi/qmd)
