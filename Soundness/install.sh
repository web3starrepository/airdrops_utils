#!/bin/bash

# 文本颜色
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # 无颜色

# 函数：显示帮助信息
show_help() {
    echo "用法: $0 [命令]"
    echo "命令:"
    echo "  install    安装 Soundness CLI 及其依赖"
    echo "  gen       生成密钥"
    echo "  help      显示此帮助信息"
}

# 函数：执行安装流程
do_install() {
    echo -e "${GREEN}🔄 正在更新系统...${NC}"

    # 检查并安装必要的系统包
    if ! command -v sudo &> /dev/null; then
        echo -e "${YELLOW}⚠️ 正在安装 sudo...${NC}"
        apt-get update && apt-get install -y sudo
    fi

    if ! command -v git &> /dev/null; then
        echo -e "${YELLOW}⚠️ 正在安装 git...${NC}"
        sudo apt-get install -y git
    fi

    # 安装编译工具链
    echo -e "${YELLOW}⚠️ 正在安装编译工具链...${NC}"
    sudo apt-get install -y build-essential gcc libssl-dev pkg-config

    # 更新系统包
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
    echo -e "${GREEN}🔽 开始安装 Soundness CLI...${NC}"

    # 清理可能存在的旧安装
    if [ -d "$HOME/.soundness" ]; then
        echo -e "${YELLOW}⚠️ 检测到旧安装，正在清理...${NC}"
        rm -rf "$HOME/.soundness"
    fi

    # 下载并执行安装脚本
    echo -e "${GREEN}📥 下载安装脚本...${NC}"
    if curl -sSL https://raw.githubusercontent.com/soundnesslabs/soundness-layer/main/soundnessup/install | bash; then
        echo -e "${GREEN}✅ 安装脚本执行完成${NC}"
    else
        echo -e "${RED}❌ 安装脚本执行失败${NC}"
        exit 1
    fi

    # 设置环境变量
    echo -e "${GREEN}🔧 配置环境变量...${NC}"
    export PATH="$HOME/.soundness/bin:$PATH"

    # 添加环境变量到shell配置
    if ! grep -q "$HOME/.soundness/bin" "$HOME/.bashrc" 2>/dev/null; then
        echo 'export PATH="$HOME/.soundness/bin:$PATH"' >> "$HOME/.bashrc"
    fi

    # 重新加载环境变量并等待
    echo -e "${GREEN}🔄 重新加载环境变量...${NC}"
    source "$HOME/.bashrc" 2>/dev/null || true
    sleep 2  # 等待环境变量生效

    # 验证 soundnessup 安装
    echo -e "${GREEN}🔍 验证 soundnessup 安装...${NC}"
    for i in {1..3}; do
        if command -v soundnessup &> /dev/null; then
            echo -e "${GREEN}✅ soundnessup 安装成功${NC}"
            break
        else
            if [ $i -eq 3 ]; then
                echo -e "${RED}❌ soundnessup 安装失败${NC}"
                echo -e "${YELLOW}ℹ️ 尝试修复安装...${NC}"
                export PATH="$HOME/.soundness/bin:$PATH"
                source "$HOME/.bashrc"
                sleep 2
                if ! command -v soundnessup &> /dev/null; then
                    echo -e "${RED}❌ 修复失败，请手动执行: source $HOME/.bashrc${NC}"
                    exit 1
                fi
            fi
            echo -e "${YELLOW}⏳ 等待 soundnessup 就绪 (尝试 $i/3)...${NC}"
            sleep 2
        fi
    done

    # 安装 soundness-cli
    echo -e "${GREEN}🔽 安装 soundness-cli...${NC}"
    soundnessup install
    sleep 2  # 等待安装完成

    # 验证 soundness-cli 安装
    echo -e "${GREEN}🔍 验证 soundness-cli 安装...${NC}"
    for i in {1..3}; do
        if command -v soundness-cli &> /dev/null; then
            echo -e "${GREEN}✅ soundness-cli 安装成功${NC}"
            break
        else
            if [ $i -eq 3 ]; then
                echo -e "${RED}❌ soundness-cli 安装失败${NC}"
                echo -e "${YELLOW}ℹ️ 请检查安装日志并重试${NC}"
                exit 1
            fi
            echo -e "${YELLOW}⏳ 等待 soundness-cli 就绪 (尝试 $i/3)...${NC}"
            sleep 2
        fi
    done

    # 验证 Soundness CLI 安装
    if command -v soundness-cli &> /dev/null; then
        echo -e "${GREEN}✅ Soundness CLI 安装成功${NC}"
    else
        echo -e "${RED}❌ Soundness CLI 安装失败，请手动检查${NC}"
        exit 1
    fi

    echo -e "${GREEN}🎉 安装完成！${NC}"
}

# 函数：执行密钥生成流程
do_gen() {
    # 验证 Soundness CLI 是否已安装
    if ! command -v soundness-cli &> /dev/null; then
        echo -e "${RED}❌ Soundness CLI 未安装，请先运行 '$0 install' 进行安装${NC}"
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
}

# 主程序
case "$1" in
    install)
        do_install
        ;;
    gen)
        do_gen
        ;;
    help|--help|-h)
        show_help
        ;;
    "")
        echo -e "${RED}❌ 错误: 未指定命令${NC}"
        show_help
        exit 1
        ;;
    *)
        echo -e "${RED}❌ 错误: 未知命令 '$1'${NC}"
        show_help
        exit 1
        ;;
esac
