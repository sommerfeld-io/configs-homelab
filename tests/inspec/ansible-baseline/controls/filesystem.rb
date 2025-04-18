title "Filesystem Check"

username = input('username', value: 'default_user')
emailAddress = input('emailAddress', value: 'noreply@example.com')
default_mode = input('default_mode', value: '0755')

control 'fs-01' do
  impact 1.0
  title 'Ensure essential directories and files are present'
  desc 'Check for the presence of essential directories and files and their permissions
    Ansible task = components/ansible/tasks/common-create-directories.yml'

  directories = [
    "/home/#{username}/.config",
    "/home/#{username}/.config/autostart",
    "/home/#{username}/work",
    "/home/#{username}/work/repos",
    "/home/#{username}/work/repos/sommerfeld-io",
    "/home/#{username}/work/repos/sommerfeld-io-archive",
    "/home/#{username}/work/repos/sebastian-sommerfeld-io",
    "/home/#{username}/tmp",
  ]

  directories.each do |directory|
    describe file(directory) do
      it { should exist }
      it { should be_directory }
      it { should be_owned_by username }
      its('mode') { should cmp default_mode }
    end
  end
end
