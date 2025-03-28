#!/bin/bash

# 文本颜色
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # 无颜色

echo -e "${GREEN}🔄 正在更新系统...${NC}"
sudo apt update && sudo apt upgrade -y

# 检查并安装 Rust
if ! command -v rustc &> /dev/null || ! command -v cargo &> /dev/null; then
    echo -e "${GREEN}🛠 正在安装 Rust...${NC}"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source $HOME/.cargo/env
    echo 'source $HOME/.cargo/env' >> ~/.bashrc
    source ~/.bashrc
else
    echo -e "${YELLOW}✅ Rust 已安装${NC}"
fi

# 显示 Rust 版本
rustc --version
cargo --version

# 检查并安装 Soundness CLI
if ! command -v soundnessup &> /dev/null; then
    echo -e "${GREEN}🔽 正在安装 Soundness CLI...${NC}"
    curl -sSL https://raw.githubusercontent.com/soundnesslabs/soundness-layer/main/soundnessup/install | bash
    source ~/.bashrc
else
    echo -e "${YELLOW}✅ Soundness CLI 已安装${NC}"
fi

# 确保 Soundness CLI 可访问
export PATH=$HOME/.soundness/bin:$PATH
echo 'export PATH=$HOME/.soundness/bin:$PATH' >> ~/.bashrc
source ~/.bashrc

# 检查 soundness-cli 是否在 PATH 中
if ! command -v soundness-cli &> /dev/null; then
    echo -e "${RED}❌ 未找到 soundness-cli！正在重新安装...${NC}"
    rm -rf ~/.soundness
    soundnessup install
    export PATH=$HOME/.soundness/bin:$PATH
    source ~/.bashrc
fi

# 验证 Soundness CLI 安装
if command -v soundness-cli &> /dev/null; then
    echo -e "${GREEN}✅ Soundness CLI 安装成功${NC}"
else
    echo -e "${RED}❌ Soundness CLI 安装失败，请手动检查${NC}"
    exit 1
fi

# 获取要生成的密钥数量
read -p "请输入要生成的密钥数量 (默认为1): " KEY_COUNT
KEY_COUNT=${KEY_COUNT:-1}

# 检查输入是否为正整数
if ! [[ "$KEY_COUNT" =~ ^[0-9]+$ ]] || [ "$KEY_COUNT" -lt 1 ]; then
    echo -e "${RED}❌ 无效的密钥数量，请输入一个正整数${NC}"
    exit 1
fi

# 创建存储助记词和公钥的目录
KEYS_DIR="$HOME/.soundness/generated_keys"
mkdir -p "$KEYS_DIR"

# 创建存储公钥的文件
PUBKEYS_FILE="$KEYS_DIR/public_keys.txt"
touch "$PUBKEYS_FILE"

# 生成指定数量的密钥
for ((i=1; i<=$KEY_COUNT; i++)); do
    KEY_NAME="key_$i"
    echo -e "${GREEN}🔑 正在生成第 $i 个密钥...${NC}"
    
    # 生成密钥并将输出保存到临时文件
    OUTPUT_FILE="$KEYS_DIR/${KEY_NAME}_info.txt"
    soundness-cli generate-key --name "$KEY_NAME" | tee "$OUTPUT_FILE"
    
    # 提取公钥信息并保存到公钥文件
    PUBLIC_KEY=$(grep "Public Key:" "$OUTPUT_FILE" | awk '{print $3}')
    echo "$PUBLIC_KEY" >> "$PUBKEYS_FILE"
    
    echo -e "${GREEN}✅ 第 $i 个密钥生成完成${NC}"
    echo -e "${YELLOW}📝 密钥信息已保存到: $OUTPUT_FILE${NC}"
    echo "----------------------------------------"
done

echo -e "${GREEN}🎉 已成功生成 $KEY_COUNT 个密钥！${NC}"
echo -e "${YELLOW}📝 所有公钥已保存到: $PUBKEYS_FILE${NC}"
echo -e "${YELLOW}⚠️ 请妥善保管保存在 $KEYS_DIR 目录下的密钥信息！${NC}"

echo -e "${GREEN}🎉 安装完成！${NC}"
