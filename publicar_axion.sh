#!/bin/bash
set -e

# Definições
REPO_URL="git@github.com:S-Marcos-S/Axion-GARNET.git"
REPO_DIR="Axion-GARNET"

echo "=== 0. Entrando na pasta axion ==="
if [ -d "axion" ]; then
    cd axion
elif [ -d "../axion" ]; then
    cd ../axion
else
    echo "ERRO: Pasta 'axion' não encontrada no mesmo nível ou acima do script."
    exit 1
fi

echo "=== 1. Iniciando o Build ==="
# Carrega o ambiente de build
if [ -f "build/envsetup.sh" ]; then
    . build/envsetup.sh
else
    echo "ERRO: build/envsetup.sh não encontrado na pasta atual."
    exit 1
fi

echo "Configurando: axion garnet gms"
# Verifica se a função axion está disponível
if ! command -v axion &> /dev/null; then
    echo "AVISO: Comando 'axion' não encontrado. Tentando 'lunch axion_garnet-ap2a-userdebug'..."
    lunch axion_garnet-ap2a-userdebug || lunch axion_garnet-userdebug
else
    axion garnet gms
fi

echo "Executando: m installclean"
m installclean

echo "Executando: m bacon"
m bacon

echo "=== 2. Identificando o arquivo ROM ==="
# Salva o diretório atual (raiz do projeto)
ROOT_DIR=$(pwd)
TARGET_DIR="out/target/product/garnet"

if [ ! -d "$TARGET_DIR" ]; then
    echo "ERRO: Diretório $TARGET_DIR não existe. O build falhou ou você não está na raiz do projeto?"
    exit 1
fi

cd "$TARGET_DIR"

# Encontra o arquivo zip mais recente (ls -t) que contém "axion" e "UNOFFICIAL"
ZIP_NAME=$(ls -t axion*UNOFFICIAL*.zip 2>/dev/null | head -n 1)

if [ -z "$ZIP_NAME" ]; then
    echo "ERRO: Nenhum arquivo ZIP correspondente (axion*UNOFFICIAL*.zip) encontrado em $TARGET_DIR"
    exit 1
fi

echo "Arquivo encontrado: $ZIP_NAME"

echo "=== 3. Upload para PixelDrain ==="
curl -T "$ZIP_NAME" -u :bf84b3a4-910b-4661-86cb-75cd27947495 https://pixeldrain.com/api/file/

echo "=== 4. Preparando Repositório Git ==="
cd "$ROOT_DIR"
# Remove o diretório se já existir para garantir um clone limpo
if [ -d "$REPO_DIR" ]; then
    rm -rf "$REPO_DIR"
fi

git clone "$REPO_URL"

echo "=== 5. Substituindo garnet.json ==="
# Tenta encontrar o garnet.json na subpasta GMS ou diretamente no diretório de build
JSON_SOURCE="$TARGET_DIR/GMS/garnet.json"

if [ ! -f "$JSON_SOURCE" ]; then
    echo "Aviso: $JSON_SOURCE não encontrado. Verificando na raiz de $TARGET_DIR..."
    JSON_SOURCE="$TARGET_DIR/garnet.json"
fi

if [ -f "$JSON_SOURCE" ]; then
    cp "$JSON_SOURCE" "$REPO_DIR/garnet.json"
    echo "Arquivo json copiado com sucesso de: $JSON_SOURCE"
else
    echo "ERRO CRÍTICO: garnet.json não encontrado nem em GMS/ nem na raiz de $TARGET_DIR."
    exit 1
fi

cd "$REPO_DIR"

echo "=== 6. Commit Automático (garnet.json) ==="
git add garnet.json
git commit -m "Nova versão da axion está sendo postada"

echo "=== 7. Atualizando Changelog ==="
CHANGELOG="changelog_garnet.txt"
DATA_HOJE=$(date "+%d/%m/%Y") 

if [ -f "$CHANGELOG" ]; then
    # Adiciona as linhas novas após a linha 1 (preserve o título/cabeçalho)
    sed -i "1a\

$DATA_HOJE\
-------------\nI'M STILL TESTING, WAIT A BIT." "$CHANGELOG"
else
    echo "AVISO: $CHANGELOG não encontrado. Criando arquivo."
    echo -e "Changelog Axion\n\n$DATA_HOJE\n-------------\nI'M STILL TESTING, WAIT A BIT." > "$CHANGELOG"
fi

echo "=== 8. Commit e Push Final ==="
git add "$CHANGELOG"
git commit -m "Update changelog"
git push

echo "=== Processo Concluído! ==="