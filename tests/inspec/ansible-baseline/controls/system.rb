title 'Global System Configuration'

username = input('username', value: 'default_user')
emailAddress = input('emailAddress', value: 'noreply@example.com')
default_mode = input('default_mode', value: '0755')

control 'system-01' do
  title 'Verify Operating System Version'
  desc 'Ensure the operating system version is as expected'

  describe os.name do
    it { should eq 'ubuntu' }
  end

  describe os.release do
    it { should eq '25.04' }
  end
end
