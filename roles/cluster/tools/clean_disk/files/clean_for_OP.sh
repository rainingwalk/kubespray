#!/usr/bin/env bash
#
# 脚本说明：
# 	本脚本用于清理服务器，释放磁盘空间

# set log file
logFile="/var/log/cleanForOP.log"
# set temp file
tempFile="/tmp/clean_for_OP_file.txt"
# docker-gc-exclude-containers file
docker_gc_exclude_containers="/etc/docker-gc-exclude-containers"

# function cut file
function cutFile() {
	# 将文件的后100行写入临时文件
	# 将临时文件写入该文件

	# get file size
	fileSize=`du -sm $1 | awk '{print $1}'`

	# write original size
	echo -e "\n the file size of $1 is ${fileSize}M" >> ${logFile}

	# cut file
	tail -n 100 $1 > ${tempFile} && cat ${tempFile} > $1

	# get file size again
	fileSize=`du -sm $1 | awk '{print $1}'`

	# write size of cut
	echo -e "the size is ${fileSize}M after clean.\n" >> ${logFile}

}

# 写入初始信息
	echo -e "the time of exec clean_mesoo_work.sh is `date +"%Y-%m-%d %H:%M:%S"`" > ${logFile}

function clear_mesos_docker_containers_log(){
	# 1 使用for循环，依次清理
	#	1.1 将文件的后100行写入临时文件
	#	1.2 将临时文件写入该文件
	# 2 删除临时文件

	# clean dir
	clean_dir="/var/lib/docker/containers /data/docker/containers
			   /var/lib/docker/volumes /data/docker/volumes
			   /var/lib/docker/overlay2 /data/docker/overlay2
                  "
	# clean file
	# .*/std.* ----> mesos log
	# *.json\.log ----> docker containers log
	# clean_file=".*/std.*|.*json\.log|.*log|.*txt"
        clean_file=".*/stdout$|.*/stderr$|.*\.json\.log$|.*\.log$|.*\.txt$"

	# 使用for循环得到所有stderr和stdout的绝对路径
	# -regextype "posix-egrep"：指定要使用的regex类型，由于find仅支持基本的regex，不支持"|"，所以需要使用扩展的regex
	for filePath in `find ${clean_dir} -type f -size +100M -mtime +7 -regextype "posix-egrep" -regex "${clean_file}" 2>/dev/null`;do
		# 调用cutFile函数，切割文件
		cutFile ${filePath}
	done
}

# 清理app的日志文件
function clearAppLog() {
	# 清理/data/log里面的日志文件
	# 1 删除4天之前的应用日志
	# 2 搜索/data/log下面所有大于5M的日志文件
	# 3 使用for循环，依次清理
	#	3.1 将文件的后100行写入临时文件
	#	3.2 将临时文件写入该文件
	# 4 删除临时文件

	# 4天前的时间戳
	days="${1:-7}"
	timestamp7DayBefore=$(date -d "-${days} day" +%s)

        # clean file
        # .*/std.* ----> mesos log
        # *.json\.log ----> docker containers log
        # clean_file=".*/std.*|.*json\.log|.*log|.*txt"
        clean_file=".*/stdout$|.*/stderr$|.*\.json\.log$|.*\.log$|.*\.txt$"

	for filePath in `find /data/log/ -mtime +1 -type f -regextype "posix-egrep" -regex "${clean_file}" 2>/dev/null`;do
		# get timestamp
		timestampFile=$(stat -c %Y ${filePath})
		# get file size
		fileSize=`du -sm ${filePath} | awk '{print $1}'`

		if [ ${timestampFile} -lt ${timestamp7DayBefore} ]
		then
			# 删除文件(修改于： 2019年4月25日10点29分)
			#/bin/rm ${filePath} 2>&1
			test -f ${filePath} && echo '' > ${filePath}
		elif [ ${fileSize} -gt 50 ]
		then
			# 调用cutFile函数，切割文件
			cutFile ${filePath}
		fi
	done
}

# 清理log文件
function clearSystemLog() {
	# 清理log日志
	# 设置日志大小
	journalctl --vacuum-size=2048M >> ${logFile} 2>&1

	# 清理messages的备份日志
	rm -rf /var/log/messages-[0-9]*
	
	# 清空messages日志
	echo > /var/log/messages
	
	# 删除30天之前的日志
	find /var/log/ -mtime +30 -name "*.log" -exec rm -rf {} \; >> ${logFile} 2>&1
	find /data/log/ -mtime +30 -name "*.log" -exec rm -rf {} \; >> ${logFile} 2>&1
}

# Docker-gc
function execDockerGC() {
	# Docker-gc
	# 1 使用命令清理容器
	# 2 使用命令清理卷
	# 3 使用命令清理镜像
	# 4 使用docker-gc最后清理一次
	
	# write init messages 
	echo -e "\n\n the time of exec docker gc is `date +"%Y-%m-%d %H:%M:%S"` \n" >> ${logFile}

	# 1 使用命令清理容器
	echo -e "使用命令清理容器的时间是 `date +"%Y-%m-%d %H:%M:%S"`" >> ${logFile}
	docker rm $(docker ps -a|grep Exited|grep -v calico|awk '{print $1}') >> /var/log/docker-gc.log 2>&1

	# 2 使用命令清理卷
	echo -e "\n\n\n使用命令清理卷是 `date +"%Y-%m-%d %H:%M:%S"`" >> ${logFile}
	docker volume rm $(docker volume ls -qf dangling=true) >> ${logFile} 2>&1

	# 3 使用命令清理镜像
	echo -e "\n\n\n使用命令清理镜像是 `date +"%Y-%m-%d %H:%M:%S"`" >> ${logFile}
	docker rmi $(docker images --filter "dangling=true" -q --no-trunc) >> ${logFile} 2>&1

	# 4 使用docker-gc最后清理一次
	echo -e "\n\n\n使用docker-gc最后清理一次是 `date +"%Y-%m-%d %H:%M:%S"`" >> ${logFile}
	# set exclude containers
	[[ ! -f ${docker_gc_exclude_containers} ]] && touch ${docker_gc_exclude_containers}
	cat > ${docker_gc_exclude_containers} <<EOF
calico*
agent-cron
monitor
agent
kubernetes*
prometheus
grafana
consul
alertmanager
blackbox-exporter
exporter-station
node-exporter
cadvisor
EOF

	# exec docker-gc
	docker run --rm \
		-v /var/run/docker.sock:/var/run/docker.sock \
		-v /etc:/etc \
		-e EXCLUDE_CONTAINERS_FROM_GC=/etc/docker-gc-exclude-containers \
		-e REMOVE_VOLUMES=1 \
		REGISTRY_URL/yks/docker-gc:latest >> ${logFile} 2>&1

	# delete dead container
	sleep 15
	docker rm -f $(docker ps -a -f status=dead -f status=created -q) >> ${logFile} 2>&1
}

# lock shell
#	保证只能有一个脚本在执行
#	如果该脚本正在运行，则不能再执行该脚本
function lock_shell() {
	# 参考：
	#	https://my.oschina.net/leejun2005/blog/108656
	#	https://blog.lilydjwg.me/2013/7/26/flock-file-lock-in-linux.40104.html

	# define var
	# get the directory of shell scripts
	scripts_dir=$(cd "$(dirname "$0")";pwd)
	# lock file name
	lockfile_name="${scripts_dir}/.$(echo $(basename $0) | awk -F . '{print $1}').lockfile"

	# lock 
	{
		# 锁定文件
		#	如果失败，则返回1
		flock -n 3

		# 判断是否已经锁定
		[ $? -eq 1 ] && { echo fail; exit; }

		# exec function
		clear_mesos_docker_containers_log
		clearAppLog
		clearSystemLog
		execDockerGC

		# delete temp file
		rm -rf ${tempFile} 2>/dev/null

		# 清空trash
		trash-empty 2>/dev/null
	} 3<>${lockfile_name}

	# delete lockfile
	rm -f ${lockfile_name}
}


# exec lock shell
lock_shell
