# syntax=docker/dockerfile:1
#
# Qwen-Image-Edit-2511 を RunPod Serverless で動かすためのワーカー。
#
# 公式の worker-comfyui にモデルを焼き込むだけの薄い派生で、handler も
# entrypoint も持たない。公式側の実装がそのまま動く。
#
# ワークフローは API の input.workflow で毎回渡す設計にしてある。出力サイズ・
# ステップ数・LoRA の差し替えを、イメージの再ビルドなしで変えられる。
# 既成ワーカーの多くはワークフローをイメージ内に固定しており、出力が正方形から
# 変えられない (指定した width/height が黙って捨てられる) 問題があった。
#
# モデルはネットワークボリュームではなくイメージに焼き込む。ボリューム経由は
# 存在するだけで容量課金が続くうえ、コールドスタートも読み出しの分だけ遅い。
# CUDA 12.8 向けにビルドされた PyTorch が入っている base を明示的に選ぶ。
# 素の 5.8.6-base は comfy-cli の既定でインストールされるため、より新しい
# CUDA 向けの PyTorch が入り、hub.json で 12.8 を指定したホストでは
# "no kernel image is available" で起動に失敗する。
# GitHub-hosted builders retain every intermediate stage locally.  The original
# Hub-oriented multi-stage layout therefore needs roughly twice the model size
# and exhausts runner disk.  Download directly into the final image in one
# layer so only the deployable 28.9-GB model payload is retained.
FROM runpod/worker-comfyui:5.8.6-base-cuda12.8.1

RUN set -eux; \
    mkdir -p /comfyui/models/diffusion_models /comfyui/models/text_encoders /comfyui/models/vae /comfyui/models/loras; \
    wget -q --tries=3 -O /comfyui/models/diffusion_models/qwen_image_edit_2511_fp8mixed.safetensors https://huggingface.co/Comfy-Org/Qwen-Image-Edit_ComfyUI/resolve/main/split_files/diffusion_models/qwen_image_edit_2511_fp8mixed.safetensors & \
    wget -q --tries=3 -O /comfyui/models/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors & \
    wget -q --tries=3 -O /comfyui/models/vae/qwen_image_vae.safetensors https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_image_vae.safetensors & \
    wget -q --tries=3 -O /comfyui/models/loras/Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors https://huggingface.co/lightx2v/Qwen-Image-Edit-2511-Lightning/resolve/main/Qwen-Image-Edit-2511-Lightning-4steps-V1.0-bf16.safetensors & \
    wait

# handler はベースイメージにも同じものが入っているが、Hub の掲載要件が
# リポジトリ内の handler.py を求めるため、明示的に置いて上書きする。
# 中身は worker-comfyui のものをそのまま使う (どちらも AGPL-3.0)。
COPY handler.py /handler.py
