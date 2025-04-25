function envio_s3() {
    echo "Fazendo envio para o S3 ..."
    echo "Iniciando envio ..."
    
    aws s3 sync ./bia/client/build/ s3://desafios-fundamentais-bia-dev --profile formacaoaws
    
    echo "Envio finalizado"
}


