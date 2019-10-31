KRILL_AUTH_TOKEN=$(docker logs krill 2>&1 | grep -Eo 'token [a-z0-9-]+$' | cut -d ' ' -f 2)
krillc="docker exec -e KRILL_CLI_SERVER=https://localhost:3000/ -e KRILL_CLI_TOKEN=${KRILL_AUTH_TOKEN} krill krillc"
$krillc add --ca child
$krillc children add --embedded --ca ta --child child --ipv4 "10.0.0.0/16"
$krillc parents add --embedded --ca child --parent ta
$krillc roas update --ca child --delta /tmp/ka/delta.1