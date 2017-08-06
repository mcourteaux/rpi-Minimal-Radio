#!/bin/bash -eux

# Start HTML server
echo "Start Server"
sudo python -m SimpleHTTPServer 80 . &
server_pid=$!

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
			echo "Exiting..."
			cat redirect.response > netcat_pipe
			killall omxplayer.bin || true
			pkill -9 $server_pid
			echo "Bye"
			killall netcat
			exit 0
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


echo "Kill Server"
pkill $server_pid
