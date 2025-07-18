title 'Ensure atuin is installed'

username = input('username', value: 'default_user')
emailAddress = input('emailAddress', value: 'noreply@example.com')
default_mode = input('default_mode', value: '0755')

control 'atuin-01' do
  impact 1.0
  title 'Check for atuin'
  desc 'Ensure atuin is installed
    Ansible tasks:
    * components/ansible/tasks/common-packages.yml'

  should_exist = [
    "/home/#{username}/.atuin/bin/atuin",
  ]
  should_exist.each do |binary|
    describe file(binary) do
      it { should exist }
      its('mode') { should cmp default_mode }
    end
  end
end
