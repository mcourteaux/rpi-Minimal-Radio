#!/bin/bash

# Start HTML server
echo "Start HTTP Server"
sudo python -m SimpleHTTPServer 80 . &
sudo_pid=$!
server_pid=$(ps --ppid $sudo_pid -o pid=)
echo "HTTP Server started with PID $server_pid under $sudo_pid"

# Make fifo
echo "Make fifo"
if [ -e volume_pipe ]; then
	rm volume_pipe
fi
mkfifo volume_pipe

echo "Make netcat fifo"
if [ -e netcat_pipe ]; then
	rm netcat_pipe
fi
mkfifo netcat_pipe

function stop_server() {
	echo "Exiting..."
	rm netcat_pipe

	echo "Kill HTTP Server..."
	sudo kill $server_pid
	sudo kill $sudo_pid
	echo "Kill netcat..."
	killall netcat

	echo "Kill omxplayer"
	killall omxplayer.bin
	rm volume_pipe

	echo "Bye"
	exit 0
}

# trap ctrl-c and call ctrl_c()
trap ctrl_c INT

function ctrl_c() {
        echo "** Trapped CTRL-C"
	stop_server
}


while true; do
(cat netcat_pipe | netcat -l 9000 &) | while IFS='' read -r line || [[ -n "$line" ]]; do
	if [ "${line:0:5}" == "GET /" ]; then
		echo $line
		cmd=${line:5}
		cmd="${cmd%\?*}"
		cmd="${cmd%\ *}"
		echo $cmd
		url=""
		if [ "$cmd" == "exit" ]; then
			cat redirect.response > netcat_pipe
			stop_server
		elif [ "$cmd" == "stop" ]; then
			killall omxplayer.bin || true
			echo -n "-" >volume_pipe
			cat redirect.response > netcat_pipe
			continue
		elif [ "$cmd" == "volume_up" ]; then
			echo -n "+" >volume_pipe
			cat redirect.response > netcat_pipe
			continue
		elif [ "$cmd" == "volume_down" ]; then
			echo -n "-" >volume_pipe
			cat redirect.response > netcat_pipe
			continue
		elif [ "$cmd" == "radio2" ]; then
			url="http://mp3.streampower.be/ra2ovl-high.mp3"
		elif [ "$cmd" == "radio1" ]; then
			url="http://mp3.streampower.be/radio1-high.mp3"
		elif [ "$cmd" == "stubru" ]; then
			url="http://mp3.streampower.be/stubru-high"
		elif [ "$cmd" == "nostalgie" ]; then
			url="http://nostalgiewhatafeeling.ice.infomaniak.ch/nostalgiewhatafeeling-128.mp3"
		elif [ "$cmd" == "qmusic" ]; then
			url="http://icecast-qmusic.cdp.triple-it.nl:80/Qmusic_be_live_96.mp3"
		elif [ "$cmd" == "rai1" ]; then
			url="http://icestreaming.rai.it/1.mp3"
		else
			echo "Unknown radio."
			continue
		fi
		
		killall omxplayer.bin || true
		echo "Starting radio: $cmd"
		echo "Starting url  : $url"
		(tail -f volume_pipe | omxplayer -o local "$url" &)

		echo "Respond with redirect"
		cat redirect.response > netcat_pipe
		echo "Done"
	fi
done
done

