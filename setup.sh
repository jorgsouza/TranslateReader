#!/bin/bash

# =============================================================================
# TranslateReader - Setup Script
# Este script configura e compila o projeto TranslateReader
# =============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "🚀 TranslateReader Setup"
echo "========================"
echo ""

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# -----------------------------------------------------------------------------
# Função para verificar dependências
# -----------------------------------------------------------------------------
check_dependencies() {
    echo -e "${BLUE}📋 Verificando dependências...${NC}"
    
    # Verificar Xcode
    if ! command -v xcodebuild &> /dev/null; then
        echo -e "${RED}❌ Xcode não encontrado!${NC}"
        echo "   Por favor, instale o Xcode da App Store"
        exit 1
    fi
    
    XCODE_VERSION=$(xcodebuild -version | head -n 1)
    echo -e "   ✅ $XCODE_VERSION"
    
    # Verificar macOS version
    MACOS_VERSION=$(sw_vers -productVersion)
    echo -e "   ✅ macOS $MACOS_VERSION"
    
    # Verificar se xcodegen está instalado
    if ! command -v xcodegen &> /dev/null; then
        echo -e "${YELLOW}⚠️  XcodeGen não encontrado. Instalando via Homebrew...${NC}"
        
        if ! command -v brew &> /dev/null; then
            echo -e "${YELLOW}   Homebrew não encontrado. Instalando...${NC}"
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
        
        brew install xcodegen
    fi
    
    echo -e "   ✅ XcodeGen instalado"
    echo ""
}

# -----------------------------------------------------------------------------
# Função para gerar o projeto Xcode
# -----------------------------------------------------------------------------
generate_project() {
    echo -e "${BLUE}🔧 Gerando projeto Xcode...${NC}"
    
    if [ -f "project.yml" ]; then
        xcodegen generate
        echo -e "   ✅ Projeto gerado: TranslateReader.xcodeproj"
    else
        echo -e "${RED}❌ Arquivo project.yml não encontrado!${NC}"
        exit 1
    fi
    echo ""
}

# -----------------------------------------------------------------------------
# Função para compilar o projeto
# -----------------------------------------------------------------------------
build_project() {
    echo -e "${BLUE}🔨 Compilando projeto...${NC}"
    
    xcodebuild -project TranslateReader.xcodeproj \
               -scheme TranslateReader \
               -configuration Debug \
               -derivedDataPath build \
               build \
               CODE_SIGN_IDENTITY="-" \
               CODE_SIGNING_REQUIRED=NO \
               CODE_SIGNING_ALLOWED=NO \
               2>&1 | while read line; do
        # Mostrar apenas erros e warnings importantes
        if [[ "$line" == *"error:"* ]]; then
            echo -e "   ${RED}$line${NC}"
        elif [[ "$line" == *"warning:"* ]]; then
            echo -e "   ${YELLOW}$line${NC}"
        elif [[ "$line" == *"BUILD SUCCEEDED"* ]]; then
            echo -e "   ${GREEN}$line${NC}"
        elif [[ "$line" == *"BUILD FAILED"* ]]; then
            echo -e "   ${RED}$line${NC}"
        fi
    done
    
    # Verificar se o build foi bem sucedido
    if [ -d "build/Build/Products/Debug/TranslateReader.app" ]; then
        echo -e "   ${GREEN}✅ Build concluído com sucesso!${NC}"
        return 0
    else
        echo -e "   ${RED}❌ Build falhou${NC}"
        return 1
    fi
}

# -----------------------------------------------------------------------------
# Função para executar o app
# -----------------------------------------------------------------------------
run_app() {
    APP_PATH="build/Build/Products/Debug/TranslateReader.app"
    
    if [ -d "$APP_PATH" ]; then
        echo -e "${BLUE}🚀 Executando TranslateReader...${NC}"
        open "$APP_PATH"
        echo -e "   ${GREEN}✅ App iniciado!${NC}"
    else
        echo -e "${RED}❌ App não encontrado. Execute o build primeiro.${NC}"
        exit 1
    fi
}

# -----------------------------------------------------------------------------
# Função para abrir no Xcode
# -----------------------------------------------------------------------------
open_xcode() {
    if [ -d "TranslateReader.xcodeproj" ]; then
        echo -e "${BLUE}📂 Abrindo no Xcode...${NC}"
        open TranslateReader.xcodeproj
    else
        echo -e "${RED}❌ Projeto não encontrado. Execute 'generate' primeiro.${NC}"
        exit 1
    fi
}

# -----------------------------------------------------------------------------
# Função para limpar build
# -----------------------------------------------------------------------------
clean_build() {
    echo -e "${BLUE}🧹 Limpando build...${NC}"
    rm -rf build/
    rm -rf TranslateReader.xcodeproj
    echo -e "   ${GREEN}✅ Limpo!${NC}"
}

# -----------------------------------------------------------------------------
# Menu de ajuda
# -----------------------------------------------------------------------------
show_help() {
    echo "Uso: ./setup.sh [comando]"
    echo ""
    echo "Comandos disponíveis:"
    echo "  generate    Gera o projeto Xcode usando XcodeGen"
    echo "  build       Compila o projeto"
    echo "  run         Executa o app compilado"
    echo "  xcode       Abre o projeto no Xcode"
    echo "  all         Executa generate + build + run"
    echo "  clean       Remove arquivos de build"
    echo "  help        Mostra esta mensagem"
    echo ""
    echo "Exemplo:"
    echo "  ./setup.sh all     # Gera, compila e executa"
    echo "  ./setup.sh xcode   # Abre no Xcode para editar"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
main() {
    case "${1:-all}" in
        generate)
            check_dependencies
            generate_project
            ;;
        build)
            check_dependencies
            generate_project
            build_project
            ;;
        run)
            run_app
            ;;
        xcode)
            check_dependencies
            generate_project
            open_xcode
            ;;
        all)
            check_dependencies
            generate_project
            build_project
            run_app
            ;;
        clean)
            clean_build
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            echo -e "${RED}Comando desconhecido: $1${NC}"
            show_help
            exit 1
            ;;
    esac
}

main "$@"
