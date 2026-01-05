#!/usr/bin/env node

const { execSync } = require('child_process');
const fs = require('fs');
const path = require('path');
const https = require('https');

const REPO = 'savioruz/owi';

function getPlatform() {
  const platform = process.platform;
  const arch = process.arch;

  if (platform === 'darwin') {
    return 'owi-macos.tar.gz';
  } else if (platform === 'linux') {
    if (arch === 'x64') {
      return 'owi-linux-x86_64.tar.gz';
    } else if (arch === 'arm64') {
      return 'owi-linux-aarch64.tar.gz';
    }
  }

  throw new Error(`Unsupported platform: ${platform} ${arch}`);
}

function getVersion() {
  const packageJson = require('./package.json');
  return packageJson.version;
}

function download(url, dest) {
  return new Promise((resolve, reject) => {
    const file = fs.createWriteStream(dest);
    
    https.get(url, { 
      headers: { 'User-Agent': 'owi-npm-installer' },
      followRedirect: true 
    }, (response) => {
      // Handle redirects
      if (response.statusCode === 302 || response.statusCode === 301) {
        download(response.headers.location, dest).then(resolve).catch(reject);
        return;
      }

      if (response.statusCode !== 200) {
        reject(new Error(`Failed to download: ${response.statusCode}`));
        return;
      }

      response.pipe(file);
      
      file.on('finish', () => {
        file.close();
        resolve();
      });
    }).on('error', (err) => {
      fs.unlink(dest, () => {});
      reject(err);
    });
  });
}

async function install() {
  try {
    const platformFile = getPlatform();
    const version = getVersion();
    
    // Use latest if version is development
    const versionTag = version === '0.0.5' ? 'latest/download' : `download/v${version}`;
    const url = `https://github.com/${REPO}/releases/${versionTag}/${platformFile}`;
    
    console.log(`Downloading owi from ${url}...`);
    
    const binDir = path.join(__dirname, 'bin');
    const tarPath = path.join(__dirname, platformFile);
    
    // Create bin directory
    if (!fs.existsSync(binDir)) {
      fs.mkdirSync(binDir, { recursive: true });
    }
    
    // Download the tarball
    await download(url, tarPath);
    
    // Extract the binary
    console.log('Extracting binary...');
    execSync(`tar -xzf ${tarPath} -C ${binDir}`, { stdio: 'inherit' });
    
    // Make it executable
    const binaryPath = path.join(binDir, 'owi');
    fs.chmodSync(binaryPath, '755');
    
    // Clean up
    fs.unlinkSync(tarPath);
    
    console.log('✓ owi installed successfully!');
    console.log('Run "owi --help" to get started.');
  } catch (error) {
    console.error('Installation failed:', error.message);
    console.error('\nYou can download the binary manually from:');
    console.error(`https://github.com/${REPO}/releases/latest`);
    process.exit(1);
  }
}

install();
