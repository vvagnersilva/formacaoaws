function build() {
    echo "Iniciando build ..."

    echo "API_URL: " $API_URL

    echo "Diretorio atual : $(pwd)"

    cd bia

    npm install 

    echo "Iniciando build ..."
    
    NODE_OPTIONS=--openssl-legacy-provider REACT_APP_API_URL=$API_URL SKIP_PREFLIGHT_CHECK=true npm run build --prefix client

    echo "Build finalizado"
    cd ..
}