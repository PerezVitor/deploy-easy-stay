# Backend

# No diretório easy-stay-backend
cd C:\Dev\Repositories\EasyStay\easy-stay-backend
wsl -d Ubuntu

docker build -t ghcr.io/perezvitor/easystay-backend:latest .
docker push ghcr.io/perezvitor/easystay-backend:latest


# Frontend

# No diretório easy-stay-frontend
execute o docker na maquina
docker build -t ghcr.io/perezvitor/easystay-frontend:latest .
docker push ghcr.io/perezvitor/easystay-frontend:latest

chmod +x deploy-easystay.sh

