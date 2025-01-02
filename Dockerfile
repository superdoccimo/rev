# Dockerfile
FROM nginx:alpine

# Nginx の設定ファイルをコンテナにコピー
COPY nginx.conf /etc/nginx/nginx.conf
COPY default.conf /etc/nginx/conf.d/default.conf

# 必要に応じて追加の操作をここに書く
# RUN apk add --no-cache ...

# コンテナ起動時に Nginx を前景モードで実行
CMD ["nginx", "-g", "daemon off;"]