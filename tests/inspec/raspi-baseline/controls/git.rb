title 'Git Configuration'

username = input('username', value: 'default_user')
emailAddress = input('emailAddress', value: 'noreply@example.com')
default_mode = input('default_mode', value: '0755')

gitconfig_path = "/home/#{username}/.gitconfig"

control 'git-01' do
  title 'Verify Git installation'
  desc 'Ensure Git is installed
    Ansible tasks:
    * components/ansible/roles/git/tasks/main.yml'

  should_exist = [
    '/usr/bin/git',
  ]
  should_exist.each do |binary|
    describe file(binary) do
      it { should exist }
      its('mode') { should cmp default_mode }
    end
  end
end

control 'git-02' do
  title 'Verify .gitconfig settings'
  desc 'Ensure the .gitconfig file contains the correct user, alias, and other configurations
    Ansible tasks:
    * components/ansible/roles/git/tasks/main.yml
    Assets:
    * components/ansible/assets/.gitconfig'

  describe file(gitconfig_path) do
    it { should exist }
    it { should be_file }
    it { should be_owned_by username }
    it { should be_grouped_into username }
    its('mode') { should cmp '0644' }
  end

  describe ini(gitconfig_path) do
    its(['user', 'email']) { should cmp emailAddress }
    its(['user', 'name']) { should cmp username }
    its(['alias', 'all']) { should cmp '"!f() { ls | xargs -I{} git -C {} $1; }; f"' }
    its(['credential', 'helper']) { should cmp 'cache --timeout=3600' }
    its(['pull', 'rebase']) { should cmp 'false' }
  end
end
