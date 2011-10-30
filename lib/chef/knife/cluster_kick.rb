#
# Author:: Philip (flip) Kromer (flip@infochimps.com)
# Copyright:: Copyright (c) 2011 Infochimps, Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require File.expand_path(File.dirname(__FILE__)+"/knife_common.rb")
require File.expand_path(File.dirname(__FILE__)+"/cluster_ssh.rb")

class Chef
  class Knife
    class ClusterKick < Chef::Knife::ClusterSsh

      import_banner_and_options(Chef::Knife::ClusterSsh)
      banner 'knife cluster kick "CLUSTER [FACET [INDEXES]]" COMMAND (options) - start a run of chef-client on each server, tailing the logs and exiting when the run completes.'
      load_deps

      option :pid_file,
        :long        => "--pid_file",
        :description => "Where to find the pid file. Typically /var/run/chef/client.pid (init.d) or /etc/sv/chef-client/supervise/pid (runit)",
        :default     => "/etc/sv/chef-client/supervise/pid"

      KICKSTART_SCRIPT = <<EOF
#!/bin/bash
set -e
<%= ((config[:verbosity].to_i > 1) ? "set -v" : "") %>

pid_file="<%= config[:pid_file] %>"

declare tail_pid

on_exit() {
  rm -f $pipe
  [ -n "$tail_pid" ] && kill $tail_pid
}

trap "on_exit" EXIT ERR

pipe=/tmp/pipe-$$
mkfifo $pipe

tail -fn0 /var/log/chef/client.log > $pipe &

tail_pid=$!

sudo kill -USR1 $(cat $pid_file)
sed -r "/(ERROR: Sleeping for [[:digit:]+] seconds before trying again|INFO: Report handlers complete)\$/{q}" $pipe
EOF

      def run
        script = Erubis::Eruby.new(KICKSTART_SCRIPT).result(:config => config)
        @name_args[1] = script
        super
      end

    end
  end
end
