AMBIENTE=$1

if [ -z "$AMBIENTE" ]; then
  echo "Uso: $0 <ambiente>"
  exit 1
fi

if [ "$AMBIENTE" != "hom" ] && [ "$AMBIENTE" != "prod" ]; then
  echo "Ambiente inválido. Use 'hom' ou 'prod'."
  exit 1
fi

# source react.sh
. react.sh
. s3.sh


echo "Fazendo deploy ..."

build

envio_s3

echo "Finalizado"