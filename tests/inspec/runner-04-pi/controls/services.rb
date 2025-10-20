title 'HTTP Service Check'

username = input('username', value: 'default_user')

control 'services-01' do
  impact 1.0
  title 'Ensure essential directories and files are present'

  directories = [
    "/home/#{username}/.docker-stacks/petclinic",
  ]
  directories.each do |directory|
    describe file(directory) do
      it { should exist }
      it { should be_directory }
      it { should be_owned_by username }
    end
  end
end

control 'http-01' do
  impact 1.0
  title 'Ensure HTTP services are running'
  desc 'Checks if the HTTP services are listening and are accessible'

  ports = [
    '8080', # petclinic
  ]
  ports.each do |port|
    describe port(port) do
      it { should be_listening }
      its('protocols') { should include 'tcp' }
    end

    describe host('localhost', port: port, protocol: 'tcp') do
      it { should be_reachable }
      it { should be_resolvable }
      its('protocol') { should eq 'tcp' }
    end

    describe http("http://localhost:#{port}") do
      its('status') { should be_in [200, 302, 307] }
    end
  end
end
