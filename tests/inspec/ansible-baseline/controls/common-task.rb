title "Ensure task is installed and configured"

username = input('username', value: 'default_user')
emailAddress = input('emailAddress', value: 'noreply@example.com')
default_mode = input('default_mode', value: '0755')

control 'task-01' do
  impact 1.0
  title 'Ensure task is installed'
  desc 'Ensure task is installed
    Ansible tasks:
    * components/ansible/tasks/common-task-setup.yml'

  binaries = [
    '/usr/bin/task',
  ]

  binaries.each do |binary|
    describe file(binary) do
      it { should exist }
      it { should be_file }
      its('mode') { should cmp default_mode }
    end
  end
end

control 'task-02' do
  impact 1.0
  title 'Ensure directories and files are present'
  desc 'Check for the presence of directories and files and their permissions
    Ansible tasks:
    * components/ansible/tasks/common-task-config.yml'

  directories = [
    "/home/#{username}/.docker-stacks",
    "/home/#{username}/.docker-stacks/ops",
    "/home/#{username}/.docker-stacks/portainer",
  ]

  directories.each do |directory|
    describe file(directory) do
      it { should exist }
      it { should be_directory }
      it { should be_owned_by username }
      its('mode') { should cmp default_mode }
    end
  end

  files = [
    "/home/#{username}/taskfile.yml",
  ]

  files.each do |file|
    describe file(file) do
      it { should exist }
      it { should be_file }
      it { should be_owned_by username }
      its('mode') { should cmp default_mode }
    end
  end
end
