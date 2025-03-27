#!/bin/bash

# 检查 privkey.txt 是否存在
if [ ! -f "Wallet.txt" ]; then
    echo "Wallet.txt 文件不存在！"
    exit 1
fi

# 读取私钥（去除可能的换行符）
PRIVKEY=$(tr -d '\n' < Wallet.txt)

# 询问要生成多少个节点
read -p "请输入要生成的 aios-node 数量: " NODE_COUNT

# 检查输入是否为数字
if ! [[ "$NODE_COUNT" =~ ^[0-9]+$ ]]; then
    echo "错误：请输入有效的数字！"
    exit 1
fi

# 开始生成 docker-compose.yaml 文件
cat <<EOF > docker-compose.yaml
version: '3.8'

services:
EOF

# 读取私钥和代理（按行读取）
declare -a WALLET_DATA
while IFS=: read -r pk proxy; do
    WALLET_DATA+=("$pk:$proxy")
done < Wallet.txt

# 检查数据行数是否足够
if [ ${#WALLET_DATA[@]} -lt $NODE_COUNT ]; then
    echo "错误：Wallet.txt 至少需要包含 $NODE_COUNT 行数据, 当前数据行数为 ${#WALLET_DATA[@]}。"
    exit 1
fi

# 为每个节点添加服务配置
for ((i=1; i<=$NODE_COUNT; i++)); do
    IFS=: read -r node_pk node_proxy <<< "${WALLET_DATA[$((i-1))]}"
    cat <<EOF >> docker-compose.yaml
  aios-node-$i:
    container_name: aios-node-$i
    image: kartikhyper/aios
    restart: unless-stopped
    environment:
      - pk=$node_pk
      - HTTP_PROXY=$node_proxy
      - HTTPS_PROXY=$node_proxy
    networks:
      - aios_network
EOF
done

# 添加网络配置
cat <<EOF >> docker-compose.yaml
networks:
  aios_network:
    driver: bridge
EOF

echo "已生成 docker-compose.yaml 文件，包含 $NODE_COUNT 个 aios-node 服务。"