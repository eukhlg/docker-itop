# docker-itop
Docker version of Combodo iTop  - A simple, web based IT Service Management tool

# How to use this image

```
docker run \
    --name my-itop \
    --volume itop_data:/var/www/html/data \
    --volume itop_log:/var/www/html/log \
    --volume itop_conf:/var/www/html/conf \
    --volume itop_extensions:/var/www/html/extensions \
    --volume itop_env_production:/var/www/html/env-production \
    --env TZ=Europe\Moscow \
    --publish 9080:80 \
    --detach \
    eukhlg/itop
```
