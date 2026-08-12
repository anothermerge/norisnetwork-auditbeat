# auditbeat::repo
# @api private
#
# @summary Manages the package repositories on the target nodes to install auditbeat
class auditbeat::repo inherits auditbeat {
  $apt_repo_url = $auditbeat::apt_repo_url ? {
    undef => "https://artifacts.elastic.co/packages/${auditbeat::major_version}.x/apt",
    default => $auditbeat::apt_repo_url,
  }
  $yum_repo_url = $auditbeat::yum_repo_url ? {
    undef => "https://artifacts.elastic.co/packages/${auditbeat::major_version}.x/yum",
    default => $auditbeat::yum_repo_url,
  }
  $gpg_key_url = $auditbeat::gpg_key_url ? {
    undef => 'https://artifacts.elastic.co/GPG-KEY-elasticsearch',
    default => $auditbeat::gpg_key_url,
  }
  $gpg_key_id = $auditbeat::gpg_key_id ? {
    '' => '46095ACC8548582C1A2699A9D27D666CD88E42B4',
    default => $auditbeat::gpg_key_id,
  }

  if ($auditbeat::manage_repo == true) and ($auditbeat::ensure == 'present') {
    case $facts['os']['family'] {
      'Debian': {
        include ::apt
        # apt-key is gone from apt 3.x (Ubuntu 25.10 and newer, Debian 13 and
        # newer), which leaves Apt_key without a usable provider. Those releases
        # get the key as a keyring referenced by signed-by instead. apt only
        # reads armoured keyrings from 2.4 onwards, so older releases keep the
        # apt-key based behaviour.
        $keyring_capable = case $facts['os']['name'] {
          'Ubuntu': { versioncmp($facts['os']['release']['full'], '22.04') >= 0 }
          'Debian': { versioncmp($facts['os']['release']['major'], '12') >= 0 }
          default:  { true }
        }
        $use_keyring = $auditbeat::apt_use_keyring ? {
          undef   => $keyring_capable,
          default => $auditbeat::apt_use_keyring,
        }
        $keyring_path = "${auditbeat::apt_keyring_dir}/${auditbeat::apt_keyring_filename}"

        if $use_keyring {
          # Other modules managing the elastic repo (elastic_stack::repo, for
          # instance) ship the very same key, and apt refuses two entries for
          # one repository that disagree on signed-by. Reuse their keyring when
          # it is already in the catalog and only reference it here, since
          # apt::keyring cannot be declared twice.
          unless defined(Apt::Keyring[$auditbeat::apt_keyring_filename]) or defined(File[$keyring_path]) {
            apt::keyring { $auditbeat::apt_keyring_filename:
              ensure => $auditbeat::ensure,
              source => $gpg_key_url,
              dir    => $auditbeat::apt_keyring_dir,
              before => Class['apt::update'],
            }
          }
          $key_params = { 'keyring' => $keyring_path }
        } else {
          $key_params = {
            'key' => {
              id     => $gpg_key_id,
              source => $gpg_key_url,
            },
          }
        }

        if !defined(Apt::Source['beats']) {
          apt::source{'beats':
            ensure   => $auditbeat::ensure,
            location => $apt_repo_url,
            release  => 'stable',
            repos    => 'main',
            *        => $key_params,
          }
          Class['apt::update'] -> Package['auditbeat']
        }
      }
      'RedHat': {
        if !defined(Yumrepo['beats']) {
          yumrepo{'beats':
            ensure   => $auditbeat::ensure,
            descr    => "Elastic repository for ${auditbeat::major_version}.x packages",
            baseurl  => $yum_repo_url,
            gpgcheck => 1,
            gpgkey   => $gpg_key_url,
            enabled  => 1,
          }
        }
      }
      'SuSe': {
        exec { 'suse_import_gpg':
          command => "/usr/bin/rpmkeys --import ${gpg_key_url}",
          unless  => "/usr/bin/test $(rpm -qa gpg-pubkey | grep -i \"${gpg_key_id}\" | wc -l) -eq 1",
          notify  => [ Zypprepo['beats'] ],
        }
        if !defined (Zypprepo['beats']) {
          zypprepo{'beats':
            baseurl     => $yum_repo_url,
            enabled     => 1,
            autorefresh => 1,
            name        => 'beats',
            gpgcheck    => 1,
            gpgkey      => $gpg_key_url,
            type        => 'yum',
          }
        }
      }
      default: {
      }
    }
  }
}
