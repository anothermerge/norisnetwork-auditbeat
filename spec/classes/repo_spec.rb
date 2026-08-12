require 'spec_helper'

describe 'auditbeat::repo', 'type' => 'class' do
  let(:pre_condition) do
    "class{'auditbeat': outputs => {'elasticsearch' => {'hosts' => ['http://localhost:9200']}}}"
  end

  def debian_facts(name, full, major)
    {
      'os' => {
        'family' => 'Debian',
        'name' => name,
        'release' => { 'full' => full, 'major' => major },
      },
      'osfamily' => 'Debian',
      'networking' => { 'hostname' => 'testhost' },
    }
  end

  context 'on a release without apt-key (Ubuntu 26.04)' do
    let(:facts) { debian_facts('Ubuntu', '26.04', '26.04') }

    it { is_expected.to compile.with_all_deps }

    it 'installs the key as a keyring instead of using apt-key' do
      is_expected.to contain_apt__keyring('elastic-keyring.asc').with(
        'source' => 'https://artifacts.elastic.co/GPG-KEY-elasticsearch',
      )
      is_expected.to contain_file('/etc/apt/keyrings/elastic-keyring.asc')
      is_expected.not_to contain_apt__key(
        'Add key: 46095ACC8548582C1A2699A9D27D666CD88E42B4 from Apt::Source beats',
      )
    end

    it 'points the source at the keyring with signed-by' do
      is_expected.to contain_file('/etc/apt/sources.list.d/beats.list').with_content(
        %r{^deb \[signed-by=/etc/apt/keyrings/elastic-keyring\.asc\] https://artifacts\.elastic\.co/packages/9\.x/apt stable main$},
      )
    end
  end

  context 'on Debian 13' do
    let(:facts) { debian_facts('Debian', '13.0', '13') }

    it { is_expected.to compile.with_all_deps }
    it { is_expected.to contain_apt__keyring('elastic-keyring.asc') }
  end

  context 'on a release predating armoured keyring support (Ubuntu 20.04)' do
    let(:facts) { debian_facts('Ubuntu', '20.04', '20.04') }

    it { is_expected.to compile.with_all_deps }

    it 'keeps the apt-key based behaviour' do
      is_expected.to contain_apt__key(
        'Add key: 46095ACC8548582C1A2699A9D27D666CD88E42B4 from Apt::Source beats',
      )
      is_expected.not_to contain_apt__keyring('elastic-keyring.asc')
    end
  end

  context 'with apt_use_keyring overridden to false on Ubuntu 26.04' do
    let(:facts) { debian_facts('Ubuntu', '26.04', '26.04') }
    let(:pre_condition) do
      "class{'auditbeat':
        apt_use_keyring => false,
        outputs         => {'elasticsearch' => {'hosts' => ['http://localhost:9200']}},
      }"
    end

    it { is_expected.to contain_apt__key('Add key: 46095ACC8548582C1A2699A9D27D666CD88E42B4 from Apt::Source beats') }
    it { is_expected.not_to contain_apt__keyring('elastic-keyring.asc') }
  end

  context 'when another module already declares the keyring' do
    let(:facts) { debian_facts('Ubuntu', '26.04', '26.04') }
    let(:pre_condition) do
      "apt::keyring{'elastic-keyring.asc':
        source => 'https://artifacts.elastic.co/GPG-KEY-elasticsearch',
      }
      class{'auditbeat': outputs => {'elasticsearch' => {'hosts' => ['http://localhost:9200']}}}"
    end

    it { is_expected.to compile.with_all_deps }

    it 'reuses it rather than declaring it twice' do
      is_expected.to contain_file('/etc/apt/sources.list.d/beats.list').with_content(
        %r{signed-by=/etc/apt/keyrings/elastic-keyring\.asc},
      )
    end
  end

  context 'with apt_manage_keyring set to false' do
    let(:facts) { debian_facts('Ubuntu', '24.04', '24.04') }
    let(:pre_condition) do
      "class{'auditbeat':
        apt_manage_keyring => false,
        outputs            => {'elasticsearch' => {'hosts' => ['http://localhost:9200']}},
      }
      # declared after auditbeat, the way another module would be
      apt::keyring{'elastic-keyring.asc':
        source => 'https://artifacts.elastic.co/GPG-KEY-elasticsearch',
      }"
    end

    it { is_expected.to compile.with_all_deps }

    # compiling at all is the assertion here: declaring the keyring in both
    # places is a duplicate declaration, whichever one Puppet evaluates first
    it 'leaves the keyring to the other module but still references it' do
      is_expected.to contain_file('/etc/apt/sources.list.d/beats.list').with_content(
        %r{signed-by=/etc/apt/keyrings/elastic-keyring\.asc},
      )
    end
  end

  context 'with a custom keyring filename and key url' do
    let(:facts) { debian_facts('Ubuntu', '26.04', '26.04') }
    let(:pre_condition) do
      "class{'auditbeat':
        apt_keyring_filename => 'beats.asc',
        gpg_key_url          => 'https://mirror.example.com/GPG-KEY-elasticsearch',
        outputs              => {'elasticsearch' => {'hosts' => ['http://localhost:9200']}},
      }"
    end

    it do
      is_expected.to contain_apt__keyring('beats.asc').with(
        'source' => 'https://mirror.example.com/GPG-KEY-elasticsearch',
      )
      is_expected.to contain_file('/etc/apt/sources.list.d/beats.list').with_content(
        %r{signed-by=/etc/apt/keyrings/beats\.asc},
      )
    end
  end
end
