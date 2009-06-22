namespace :test do
  def parallel_with_copied_envs(num_processes)
    plugin_root = File.join(File.dirname(__FILE__), '..')
    require File.join(plugin_root, 'lib', 'parallel_tests')

    num_processes = (num_processes||2).to_i
    ParallelTests.with_copied_envs(RAILS_ROOT, num_processes) do
      yield(num_processes)
    end
  end

  namespace :parallel do
    desc "prepare parallel test running by calling db:reset for every env needed with test:parallel:"
    task :prepare, :count do |t,args|
      parallel_with_copied_envs(args[:count]) do |num_processes|
        num_processes.times do |i|
          env = "test#{i==0?'':i+1}"
          puts "RAILS_ENV=#{env} rake db:reset"
          system("RAILS_ENV=#{env} rake db:reset")
        end
      end
    end
  end

  desc "run tests in parallel with test:parallel[count]"
  task :parallel, :count do |t,args|
    parallel_with_copied_envs(args[:count]) do |num_processes|
      puts "running tests in #{num_processes} processes"
      start = Time.now

      groups = ParallelTests.tests_in_groups(RAILS_ROOT,args[:count].to_i)
      puts "#{groups.sum{|g|g.size}} tests in #{groups[0].size} tests per process"

      #run each of the groups
      pids = []
      num_processes.times do |i|
        puts "starting process #{i+1}"
        pids << Process.fork do
          require_list = groups[i].map { |filename| "\"#{filename}\"" }.join(",")
          puts   "RAILS_ENV=test#{i==0?'':i+1} ruby -Itest -e '[#{require_list}].each {|f| require f }'"
          system "RAILS_ENV=test#{i==0?'':i+1} ruby -Itest -e '[#{require_list}].each {|f| require f }'"
        end
      end

      #handle user interrup
      interrupt_handler = lambda do
        STDERR.puts "interrupt, exiting ..."
        pids.each { |pid| Process.kill "KILL", pid }
        exit 1
      end
      Signal.trap 'SIGINT', interrupt_handler

      #wait for everybody to finish
      pids.each{ Process.wait }

      #report total time taken
      puts "Took #{Time.now - start} seconds"
    end
  end

  # TODO: Make this work.
  # task :parallel_features, :count do |t,args|
  #   parallel_with_copied_envs(args[:count]) do |num_processes|
  #     puts "running features in #{num_processes} processes"
  #     start = Time.now

  #     groups = ParallelTests.features_in_groups(RAILS_ROOT,args[:count].to_i)
  #     puts "#{groups.sum{|g|g.size}} features in #{groups[0].size} features per process"

  #     #run each of the groups
  #     pids = []
  #     num_processes.times do |i|
  #       puts "starting process #{i+1}"
  #       pids << Process.fork do
  #         require_list = groups[i].join(" ") # .map { |filename| "\"#{filename}\"" }.join(",")
  #         puts   "RAILS_ENV=test#{i==0?'':i+1} cucumber -r features #{require_list}"
  #         system "RAILS_ENV=test#{i==0?'':i+1} cucumber -r features #{require_list}"
  #       end
  #     end

  #     #handle user interrup
  #     interrupt_handler = lambda do
  #       STDERR.puts "interrupt, exiting ..."
  #       pids.each { |pid| Process.kill "KILL", pid }
  #       exit 1
  #     end
  #     Signal.trap 'SIGINT', interrupt_handler

  #     #wait for everybody to finish
  #     pids.each{ Process.wait }

  #     #report total time taken
  #     puts "Took #{Time.now - start} seconds"
  #   end
  # end
end
