module ParallelTests
  extend self

  def with_copied_envs(root, num_processes)
    envs = []
    2.upto(num_processes){|i| envs << "#{root}/config/environments/test#{i}.rb"}
    envs.each do |file|
      File.open(file, 'w') do |f|
        f.puts "#DO NOT MODIFY--WILL BE OVERWRITTEN!!!"
        f.puts File.read("#{root}/config/environments/test.rb")
      end
    end
    yield
    envs.each{|f| `rm #{f}`}
  end

  #find all tests and partition them into groups
  def tests_in_groups(root, num)
    tests = (Dir["#{root}/test/**/*_test.rb"]).sort
    in_groups_of(tests, num)
  end

  #find all features and partition them into groups
  def features_in_groups(root, num)
    features = (Dir["#{root}/features/**/*.feature"]).sort
    in_groups_of(features, num)
  end

  private

  def in_groups_of(items, num)
    groups = []
    num.times{|i| groups[i]=[]}

    loop do
      num.times do |i|
        return groups if items.empty?
        groups[i] << items.shift
      end
    end

    groups
  end
end
