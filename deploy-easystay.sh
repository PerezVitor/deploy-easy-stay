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

# Configurar .env do backend
print_status "Configurando backend..."

if [ ! -f "easy-stay-backend/.env" ]; then
    if [ -f "easy-stay-backend/.env.example" ]; then
        cp easy-stay-backend/.env.example easy-stay-backend/.env
        print_success "Arquivo .env criado a partir do .env.example"
    else
        print_warning "Criando .env básico..."
        cat > easy-stay-backend/.env << EOF
APP_NAME="EasyStay"
APP_ENV=production
APP_KEY=
APP_DEBUG=false
APP_URL=http://138.201.244.103:8090
APP_TIMEZONE=America/Sao_Paulo
FRONTEND_URL=http://138.201.244.103:3005

# Disable Telescope in production
TELESCOPE_ENABLED=false

DB_CONNECTION=pgsql
DB_HOST=postgres
DB_PORT=5432
DB_DATABASE=easystay
DB_USERNAME=easystay_user
DB_PASSWORD=EasyStay2024!Strong

REDIS_HOST=redis
REDIS_PORT=6379
CACHE_DRIVER=redis
SESSION_DRIVER=redis
QUEUE_CONNECTION=redis

JWT_TTL=60
AUTH_MAX_INACTIVE_TIME=1440
AUTH_TOKEN_REFRESH_PERCENTAGE=80
AUTH_TOKEN_REFRESH_COOLDOWN=15

LOG_CHANNEL=stack
LOG_LEVEL=error
EOF
    fi
fi

# Adicionar variáveis se não existirem
print_status "Configurando variáveis adicionais..."
if ! grep -q "CLOUDINARY_CLOUD_NAME=" easy-stay-backend/.env; then
    echo "" >> easy-stay-backend/.env
    echo "# Cloudinary" >> easy-stay-backend/.env
    echo "CLOUDINARY_CLOUD_NAME=" >> easy-stay-backend/.env
    echo "CLOUDINARY_API_KEY=" >> easy-stay-backend/.env
    echo "CLOUDINARY_API_SECRET=" >> easy-stay-backend/.env
fi

if ! grep -q "SUPABASE_URL=" easy-stay-backend/.env; then
    echo "" >> easy-stay-backend/.env
    echo "# Supabase" >> easy-stay-backend/.env
    echo "SUPABASE_URL=" >> easy-stay-backend/.env
    echo "SUPABASE_SERVICE_ROLE_KEY=" >> easy-stay-backend/.env
    echo "SUPABASE_KEY=" >> easy-stay-backend/.env
    echo "SUPABASE_BUCKET=" >> easy-stay-backend/.env
fi

if ! grep -q "RESEND_API_KEY=" easy-stay-backend/.env; then
    echo "" >> easy-stay-backend/.env
    echo "# Resend Email" >> easy-stay-backend/.env
    echo "RESEND_API_KEY=" >> easy-stay-backend/.env
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

# Gerar APP_KEY se necessário
if ! grep -q "APP_KEY=base64:" easy-stay-backend/.env; then
    print_status "Gerando APP_KEY do Laravel..."
    docker cp easy-stay-backend/.env easystay-backend:/var/www/.env
    docker-compose -f docker-compose.easystay.yml exec backend php artisan key:generate --force
    docker cp easystay-backend:/var/www/.env easy-stay-backend/.env
    print_success "APP_KEY gerada ✓"
fi

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
