#!/usr/bin/env bash
# crisp module: ai-health
# AI toolkit health check (ML tools, GPU, CUDA compatibility)

[[ -n "${CRISP_MOD_AIHEALTH_LOADED:-}" ]] && return 0
readonly CRISP_MOD_AIHEALTH_LOADED=1

# T19: Main health report — orchestrates T16 (detection), T17 (GPU),
# T18 (release notifications)
_crisp_ai_health() {
  local ver latest pkg gpu driver cuda_ver torch_cuda

  echo "🤖 AI Toolkit Health Report"
  echo "─────────────────────────────"

  # ── T16+T18: pip3 ML packages with release notifications ──
  local -a pip_pkgs=(torch transformers vllm ollama tensorflow jax diffusers accelerate peft)
  for pkg in "${pip_pkgs[@]}"; do
    ver="$(pip3 list 2>/dev/null | grep -i "^${pkg}[[:space:]]" | awk '{print $NF}')"
    if [[ -n "$ver" ]]; then
      latest="$(pip3 index versions "$pkg" 2>/dev/null | grep "LATEST:" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
      if [[ -n "$latest" ]] && [[ "$ver" != "$latest" ]]; then
        echo "  ⚠  ${pkg} ${ver} → ${latest} (update available)"
      else
        echo "  ✅ ${pkg} ${ver}"
      fi
    else
      echo "  ⚠  ${pkg} not installed"
    fi
  done

  # ── T16: brew packages ──
  if command -v brew &>/dev/null; then
    local -a brew_pkgs=(ollama llama.cpp lp.cpp mlx)
    for pkg in "${brew_pkgs[@]}"; do
      if brew list --formula "$pkg" &>/dev/null 2>&1; then
        ver="$(brew list --versions "$pkg" 2>/dev/null | awk '{print $NF}')"
        echo "  ✅ ${pkg} ${ver} (brew)"
      fi
    done
  fi

  # ── T16: binary checks ──
  if command -v ollama &>/dev/null; then
    ver="$(ollama --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
    [[ -n "$ver" ]] && echo "  ✅ ollama ${ver} (binary)" || echo "  ✅ ollama installed (binary)"
  fi
  if command -v vllm &>/dev/null; then
    ver="$(vllm --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
    [[ -n "$ver" ]] && echo "  ✅ vllm ${ver} (binary)" || echo "  ✅ vllm installed (binary)"
  fi
  if command -v llama.cpp &>/dev/null; then
    ver="$(llama.cpp --version 2>/dev/null | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
    [[ -n "$ver" ]] && echo "  ✅ llama.cpp ${ver} (binary)" || echo "  ✅ llama.cpp installed (binary)"
  fi

  # ── T17: GPU / CUDA compatibility ──
  echo "─────────────────────────────"
  if [[ "$CRISP_OS" == "macos" ]]; then
    gpu="$(system_profiler SPDisplaysDataType 2>/dev/null | grep "Chipset Model" | sed 's/.*Chipset Model: //' | head -1)"
    echo "  GPU: ${gpu:-unknown} (no CUDA)"
  elif [[ "$CRISP_OS" == "linux" ]]; then
    driver="$(nvidia-smi 2>/dev/null | grep "Driver Version" | awk '{print $NF}')"
    cuda_ver="$(nvidia-smi 2>/dev/null | grep "CUDA Version" | awk '{print $NF}')"
    if [[ -n "$driver" ]]; then
      echo "  GPU: NVIDIA Driver ${driver}, CUDA ${cuda_ver:-unknown}"
    else
      echo "  GPU: not detected (nvidia-smi not available)"
    fi
    torch_cuda="$(python3 -c "import torch; print(torch.version.cuda if torch.cuda.is_available() else 'N/A')" 2>/dev/null)"
    if [[ -n "$torch_cuda" ]] && [[ "$torch_cuda" != "N/A" ]]; then
      echo "  PyTorch CUDA: ${torch_cuda}"
    fi
  fi

  echo "─────────────────────────────"
}
