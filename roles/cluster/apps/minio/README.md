参考网址： 
https://github.com/minio 
https://hub.docker.com/u/minio 

1. 安装选项
所有的安装选项可以在 defaults/main.yml 中配置，有如下选项可以设置：
TENANT_NAME:         租户的名称，默认设置为minio-default-tenant。
SEVERS_COUNT:        Pod实例的个数。
VOLUMES_COUNT:       底层存储PVC的数量，必须为SEVERS_COUNT的整数倍。
CAPACITY:            总存储容量大小。
TENANT_NAMESPACE:    部署Pod实例的命名空间。注意一个命命空间只可以部署一个租户。
STORAGE_CLASS_NAME:  用于自动生成PV的存储类。注意将此存储类的reclaim policy设置为Retain，以防止扩容或升级时可能的数据丢失。

2. 如何访问minio server的console？
登录minio server的console界面后可以在创建的租户里面操作bucket, object等。
minio server的console的服务可以通过如下命令查看：

    kubectl get svc -n minio-default-tenant minio-default-tenant-console

注意这个一个ClusterIP类型的服务，只能在集群内部访问。可以通过如下命令，通过port forward的方式到本地访问:

    kubectl port-forward svc/minio-default-tenant-console -n minio-default-tenant 9443:9443 

这样在本地可以通过 https://127.0.0.1:9443/ 访问此console。console的用户名密码存放在secret中，可以通过如下命令获取secret并进行base64解码得到用户名密码：

    kubectl get secret -n minio-default-tenant minio-default-tenant-console-secret -o yaml

3. 如何访问minio operator的console？
登录minio operator的console界面可以管理/增加/删除租户。
__minio operator的console的服务可以通过如下命令查看：__

    kubectl get svc -n minio-operator console

和minio server的console一样，minio operator的console也只能在集群内部访问，可以通过如下命令在本地访问：

    kubectl minio proxy

此命令会输出访问console页面所需要的token。

4. 如何获取minio server的access key和secret key?
当需要在minio操作和管理数据时，需要minio server的access key和secret key，这些key保存在secret中，可以通过如下命令获取并进行base64解码得到：

    kubectl get secret -n minio-default-tenant minio-default-tenant-creds-secret -o yaml

5. 扩容
扩容操作可以通过console页面或命令行实现。
参考： https://github.com/minio/operator/blob/master/docs/expansion.md

kubectl get secret -n minio-operator minio-operator-token-9w8g5 -o yaml

6. 客户端访问
客户端访问方式可以参考： https://docs.min.io/docs/golang-client-quickstart-guide
SDK访问可以参考： https://docs.min.io/docs/golang-client-quickstart-guide.html


kubectl create ns tenant1-ns
kubectl create secret generic tenant1-secret --from-literal=accesskey=YOUR-ACCESS-KEY --from-literal=secretkey=YOUR-SECRET-KEY --namespace tenant1-ns
kubectl create -f https://raw.githubusercontent.com/minio/operator/master/examples/console-secret.yaml --namespace tenant1-ns
kubectl minio tenant create --name tenant1 --secret tenant1-secret --servers 4 --volumes 16 --capacity 16Ti --namespace tenant1-ns --console-secret console-secret