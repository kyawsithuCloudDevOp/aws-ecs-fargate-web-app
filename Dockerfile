FROM public.ecr.aws/nginx/nginx:latest
COPY ./site /usr/share/nginx/html
EXPOSE 80
