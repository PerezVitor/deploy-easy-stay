#!/bin/bash

# Deploy EasyStay - VM Produção
# IP: 138.201.244.103

set -e

echo "🚀 Iniciando deploy do EasyStay..."

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verificar se estamos no diretório correto
if [ ! -f "docker-compose.easystay.yml" ]; then
    print_error "docker-compose.easystay.yml não encontrado!"
    print_error "Execute este script no diretório raiz do projeto"
    exit 1
fi

# Verificar Docker
if ! command -v docker &> /dev/null; then
    print_error "Docker não está instalado!"
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    print_error "Docker Compose não está instalado!"
    exit 1
fi

print_success "Docker verificado ✓"

# Login no GitHub Container Registry
print_status "Fazendo login no GitHub Container Registry..."
echo "Certifique-se de ter feito login: docker login ghcr.io -u perezvitor"

# Verificar se .env existe (para variáveis do docker-compose)
if [ ! -f ".env" ]; then
    print_warning "Criando arquivo .env para docker-compose..."
    cat > .env << EOF
# Supabase
SUPABASE_URL=
SUPABASE_SERVICE_ROLE_KEY=
SUPABASE_KEY=
SUPABASE_BUCKET=

# Cloudinary
CLOUDINARY_CLOUD_NAME=
CLOUDINARY_API_KEY=
CLOUDINARY_API_SECRET=

# Resend Email
RESEND_API_KEY=
EOF
    print_warning "Configure as variáveis no arquivo .env antes de continuar!"
fi

# Parar containers existentes
print_status "Parando containers existentes..."
docker-compose -f docker-compose.easystay.yml down 2>/dev/null || true

# Pull das imagens mais recentes
print_status "Baixando imagens mais recentes..."
docker-compose -f docker-compose.easystay.yml pull

# Subir os serviços
print_status "Subindo os serviços..."
docker-compose -f docker-compose.easystay.yml up -d

print_status "Aguardando serviços ficarem prontos..."
sleep 15

# Verificar status
print_status "Verificando status dos containers..."
docker-compose -f docker-compose.easystay.yml ps

# Aguardar PostgreSQL ficar pronto
print_status "Aguardando PostgreSQL..."
timeout=60
counter=0
while ! docker-compose -f docker-compose.easystay.yml exec -T postgres pg_isready -U easystay_user -d easystay > /dev/null 2>&1; do
    if [ $counter -eq $timeout ]; then
        print_error "Timeout aguardando PostgreSQL"
        exit 1
    fi
    sleep 2
    counter=$((counter + 2))
    echo -n "."
done
echo
print_success "PostgreSQL pronto ✓"

# Gerar APP_KEY
print_status "Gerando APP_KEY do Laravel..."
docker-compose -f docker-compose.easystay.yml exec backend php artisan key:generate --force || print_warning "Não foi possível gerar APP_KEY automaticamente"

# Configurar CORS para permitir frontend
print_status "Configurando CORS..."
docker-compose -f docker-compose.easystay.yml exec backend sed -i "/'http:\/\/127.0.0.1:3000',/a\\        'http://138.201.244.103:3005'," /var/www/config/cors.php 2>/dev/null || true

# Executar migrações
print_status "Executando migrações do banco..."
docker-compose -f docker-compose.easystay.yml exec backend php artisan migrate --force

# Executar seeders (comentado - descomente se necessário)
# print_status "Executando seeders..."
# docker-compose -f docker-compose.easystay.yml exec backend php artisan db:seed --force

# Criar link de storage
print_status "Criando link de storage..."
docker-compose -f docker-compose.easystay.yml exec backend php artisan storage:link || true

# Otimizações do Laravel
print_status "Aplicando otimizações do Laravel..."
docker-compose -f docker-compose.easystay.yml exec backend php artisan config:clear
docker-compose -f docker-compose.easystay.yml exec backend php artisan config:cache
docker-compose -f docker-compose.easystay.yml exec backend php artisan route:cache
docker-compose -f docker-compose.easystay.yml exec backend php artisan view:cache
docker-compose -f docker-compose.easystay.yml exec backend php artisan optimize

# Verificar permissões de storage
print_status "Corrigindo permissões de storage..."
docker-compose -f docker-compose.easystay.yml exec backend chown -R www:www /var/www/storage /var/www/bootstrap/cache
docker-compose -f docker-compose.easystay.yml exec backend chmod -R 775 /var/www/storage /var/www/bootstrap/cache

# Verificar status final
print_status "Status final dos serviços:"
docker-compose -f docker-compose.easystay.yml ps

print_success "🎉 Deploy concluído com sucesso!"
echo
echo "📱 Aplicações disponíveis:"
echo "   Frontend: http://138.201.244.103:3005"
echo "   Backend:  http://138.201.244.103:8090"
echo "   API:      http://138.201.244.103:8090/api/v1"
echo
echo "📊 Comandos úteis:"
echo "   Logs: docker-compose -f docker-compose.easystay.yml logs -f"
echo "   Status: docker-compose -f docker-compose.easystay.yml ps"
echo "   Parar: docker-compose -f docker-compose.easystay.yml down"
echo
echo "🔧 Troubleshooting:"
echo "   Backend logs: docker-compose -f docker-compose.easystay.yml logs backend"
echo "   Frontend logs: docker-compose -f docker-compose.easystay.yml logs frontend"
echo "   PostgreSQL logs: docker-compose -f docker-compose.easystay.yml logs postgres"
echo "   Reiniciar: docker-compose -f docker-compose.easystay.yml restart [serviço]"
echo
echo "⚙️ Configurações importantes:"
echo "   1. Configure as variáveis de ambiente em easy-stay-backend/.env"
echo "   2. Adicione as credenciais do Supabase, Cloudinary e Resend"
echo "   3. Atualize as URLs no .env se necessário"
