title 'SSH Configuration and Keypair Verification'

username = input('username', value: 'default_user')
emailAddress = input('emailAddress', value: 'noreply@example.com')
default_mode = input('default_mode', value: '0755')

ssh_key_path = "/home/#{username}/.ssh/id_rsa"

control 'ssh-01' do
  title 'Verify SSH keypair presence'
  desc 'Ensure the SSH private and public key files are present and have correct permissions
    Ansible tasks:
    * components/ansible/tasks/common-ssh.yml'

  describe file(ssh_key_path) do
    it { should exist }
    it { should be_file }
    it { should be_owned_by username }
    it { should be_grouped_into username }
    its('mode') { should cmp '0600' }
  end

  describe file("#{ssh_key_path}.pub") do
    it { should exist }
    it { should be_file }
    it { should be_owned_by username }
    it { should be_grouped_into username }
    its('mode') { should cmp '0644' }
  end
end

control 'ssh-02' do
  title 'Verify SSH key strength'
  desc 'Ensure the SSH private key has the correct strength (bits)
    Ansible tasks:
    * components/ansible/tasks/common-ssh.yml'

  describe command("ssh-keygen -lf #{ssh_key_path}") do
    its('stdout') { should match /4096/ }
    its('exit_status') { should eq 0 }
  end
end
