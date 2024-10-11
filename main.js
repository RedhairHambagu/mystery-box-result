const { app, BrowserWindow, ipcMain,session } = require('electron');
const path = require('path');

let mainWindow;

let store; // 声明 store 变量

async function createWindow() {
    // 动态导入 electron-store
    const { default: ElectronStore } = await import('electron-store');
    store = new ElectronStore();
    mainWindow = new BrowserWindow({
        width: 800,
        height: 600,
        webPreferences: {
            preload: path.join(__dirname, 'renderer.js'),
            contextIsolation: true,
            enableRemoteModule: false,
        },
    });

    mainWindow.loadFile('index.html');
        // 开启开发者工具
        mainWindow.webContents.openDevTools();

   

    mainWindow.webContents.on('did-navigate', (event, url) => {
        // if (url.includes('your-login-success-url')) {
            const token = extractTokenFromUrl(url);
            mainWindow.webContents.send('token-extracted', token);
        // }
    });

    // 监听网络请求
    setTimeout(() => {
        const filter = {
            urls: ['https://logtake.weidian.com/h5collector/webcollect/3.0?type=spider*']
        };

        session.defaultSession.webRequest.onBeforeSendHeaders(filter, (details, callback) => {
            const cookie = details.requestHeaders ? (details.requestHeaders['Cookie'] || '') : '';
            
            console.log('Cookie:', cookie);

            // 存储 Cookie
            store.set('authCookie', cookie);

            // 发送到 renderer.js
            mainWindow.webContents.send('request-captured', { url: details.url, cookie });

            callback({ cancel: false });
        });
    }, 3000); // 等待 3 秒后开始监听


}

// 创建新窗口的函数
function createLoginWindow(url) {
    const loginWindow = new BrowserWindow({
        width: 800,
        height: 600,
        webPreferences: {
            contextIsolation: true,
            enableRemoteModule: false,
        },
    });

    loginWindow.loadURL(url);
    loginWindow.webContents.openDevTools(); // 开启开发者工具
}

// 创建盲盒窗口的函数
function createMysteryBoxWindow(url) {
    const mysteryBoxWindow = new BrowserWindow({
        width: 800,
        height: 600,
        webPreferences: {
            contextIsolation: true,
            enableRemoteModule: false,
        },
    });
    console.log('打开盲盒记录界面')
    mysteryBoxWindow.loadURL(url);
    mysteryBoxWindow.webContents.openDevTools(); // 开启盲盒窗口的开发者工具
   // 延迟监听网络请求
   setTimeout(() => {
    const filter = {
        urls: ['https://thor.weidian.com/skittles/share.getConfig/*']
    };

    session.defaultSession.webRequest.onBeforeRequest(filter, (details, callback) => {
        if (details.url.includes('wdtoken=')) {
            const urlParams = new URLSearchParams(new URL(details.url).search);
            const wdtoken = urlParams.get('wdtoken'); // 提取 wdtoken
            const underscoreParams = {}; // 存储 "_" 对应的参数
    
            // 提取所有以 "_" 开头的参数
            for (const [key, value] of urlParams.entries()) {
                if (key.startsWith('_')) {
                    underscoreParams[key] = value;
                }
            }
    
            console.log('wdtoken:', wdtoken);
            console.log('Underscore Parameters:', underscoreParams);
    
            // 发送到 renderer.js
            mainWindow.webContents.send('wdtoken-extracted', { wdtoken, underscoreParams });
            console.log('监听')
            // const cookie = details.requestHeaders['Cookie'] || '';
            // console.log(cookie, '监听');
            // mainWindow.webContents.send('request-captured', { url: details.url, cookie });
        }
        callback({});
    });
}, 3000); // 等待 3 秒后开始监听
  // 延迟监听网络请求
  setTimeout(() => {
    const filter = {
        urls: ['https://logtake.weidian.com/h5collector/webcollect/3.0?type=spider*']
    };

    session.defaultSession.webRequest.onBeforeSendHeaders(filter, (details, callback) => {
        
        const cookie = details.requestHeaders ? (details.requestHeaders['Cookie'] || '') : '';
        const referer = details ? (details['referrer'] || '') : '';
                    // 存储 Cookie
            // store.set('authCookie', cookie);
        // console.log('Cookie:', cookie);
        // console.log('Referer:', referer);

        // 发送到 renderer.js
        mainWindow.webContents.send('request-captured', { url: details.url, cookie, referer });

        callback({});
    });
}, 3000); // 等待 3 秒后开始监听
}


ipcMain.on('open-mystery-box-window', (event, url) => {
    createMysteryBoxWindow(url);
});

function extractTokenFromUrl(url) {
    const urlParams = new URLSearchParams(new URL(url).search);
    return urlParams.get('token'); // 假设 token 在 URL 中
}

app.whenReady().then(createWindow);

app.on('window-all-closed', () => {
    if (process.platform !== 'darwin') {
        app.quit();
    }
});

app.on('activate', () => {
    if (BrowserWindow.getAllWindows().length === 0) {
        createWindow();
    }
});


    // 新增函数：从新 URL 获取 Item 信息
    function fetchItemsFromNewUrl(url) {
        const cookie = store.get('authCookie'); // 获取登录时的 Cookie
        // console.log(cookie) 
        fetch(url, {
            method: 'GET',
            headers: {
                'Referer': 'https://h5.weidian.com/', // 添加 Referer 头
                'Cookie': cookie // 使用登录时的 Cookie
            }
        })
        .then(response => response.json())
        .then(data => {
            // 处理返回的数据
            const results = data.result['boxRecordList']; // 根据实际数据结构调整
            mainWindow.webContents.send('items-fetched', results); // 发送新获取的 Item 信息
        })
        .catch(error => {
            console.error('Error fetching items from new URL:', error);
        });
    }
    

ipcMain.on('fetch-item',(event, url) => {
    fetchItemsFromNewUrl(url);
    console.log('fetch item')
});

ipcMain.on('open-login-window', (event, url) => {
    createLoginWindow(url);
    console.log('create login window')
});

ipcMain.on('request-cookie', (event) => {
    const cookie = store.get('authCookie');
    event.sender.send('cookie-response', cookie);
});

ipcMain.on('fetch-auth-and-name', (event, { url }) => {
    const cookie = store.get('authCookie');

    // session.defaultSession.webRequest.onBeforeSendHeaders((details, callback) => {
    //     details.requestHeaders['Cookie'] = cookie;
    //     details.requestHeaders['User-Agent'] = 'Mozilla/5.0 (iPhone; CPU iPhone OS 15_6_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 MicroMessenger/8.0.39(0x1800272d) NetType/WIFI Language/en miniProgram/wx4b74228baa15489a';
    //     callback({ requestHeaders: details.requestHeaders });
    // });

    fetch(url, {
        method: 'GET',
        headers: {
            'Referer': 'https://h5.weidian.com/',
            'Cookie': cookie // 使用登录时的 Cookie
        }
    })
    .then(response => {
        console.log('Response:', response);

        if (!response.ok) {
            throw new Error(`HTTP error! status: ${response.status}`);
        }

        return response.json();
    })
    .then(data => {
        // 延迟处理数据
        setTimeout(() => {
            console.log('Data:', data);
        const { auth, name } = data.result.boxInfo;
        event.sender.send('auth-and-name-response', { auth, name });
    }, 1000); // 延迟 3 秒
    })
    .catch(error => {
        console.error('Error fetching auth and name:', error);
        event.sender.send('auth-and-name-response', { auth: 'N/A', name: 'N/A' });
    });
});

async function getCompleteList(auth) {
    const itemFullUrl = `https://thor.91ruyu.com/pyxis/pyxis.mysteryBoxActivityInfo/1.0?param={"auth":"${auth}","flowAction":"mystery_box_main_page","showSold":true}&_=${Date.now()}`;
    const cookie = store.get('authCookie'); // 获取存储的 Cookie

    const response = await fetch(itemFullUrl, {
        method: 'GET',
        headers: {
            'Referer': 'https://h5.weidian.com/',
            'Cookie': cookie
        }
    });

    const data = await response.json();
    console.log(data);
    return data.result.prizeList.map(item => item.name);
}

ipcMain.handle('get-complete-list', async (event, auth) => {
    try {
        const completeList = await getCompleteList(auth);
        return completeList;
    } catch (error) {
        console.error('Error fetching complete list:', error);
        return [];
    }
});