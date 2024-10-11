const { ipcRenderer } = require('electron');

let itemid_list = []; // 动态获取的 Item ID 列表
let wdtoken = ''; // 存储提取的 wdtoken
let underscoreParams = {}; // 存储 "_" 对应的参数

ipcRenderer.on('token-extracted', (event, token) => {
    localStorage.setItem('authToken', token);
    console.log(token)
    // callApiWithToken(token);
});
ipcRenderer.on('wdtoken-extracted', (event, { wdtoken: extractedWdtoken, underscoreParams: extractedUnderscoreParams }) => {
    wdtoken = extractedWdtoken; // 存储提取的 wdtoken
    underscoreParams = extractedUnderscoreParams; // 存储提取的 "_" 参数
    document.getElementById('fetch-items-button').style.display = 'block'; // 显示获取 Item 信息的按钮
});

ipcRenderer.on('request-captured', (event, { url, cookie }) => {
    console.log('Captured URL:', url);
    console.log('Captured Cookie:', cookie);
    localStorage.setItem('authCookie', cookie);
    document.getElementById('cookie-info').innerText = `登录 Cookie: ${cookie}`;
});

let currentPage = 0;
document.addEventListener('DOMContentLoaded', () => {
    const tabContainer = document.createElement('div');
    tabContainer.id = 'tab-container';
    document.body.insertBefore(tabContainer, document.getElementById('item-container'));

    // 初始化 currentResults
    localStorage.setItem('currentResults', JSON.stringify([]));

    // 处理登录按钮点击事件
    document.getElementById('login-button').addEventListener('click', (event) => {
        const loginUrl = 'https://sso.weidian.com/login/index.php'; // 登录链接
        console.log('Attempting to open login window with URL:', loginUrl);
        ipcRenderer.send('open-login-window', loginUrl); // 发送消息以打开新窗口
    });

    // 打开盲盒界面
    document.getElementById('open-mystery-box').addEventListener('click', () => {
        const mysteryBoxUrl = 'https://h5.weidian.com/m/mystery-box/list.html#/'; // 盲盒链接
        console.log('Attempting to open mystery box window with URL:', mysteryBoxUrl);
        ipcRenderer.send('open-mystery-box-window', mysteryBoxUrl); // 发送消息以打开新窗口
    });

    // 新增按钮点击事件
    document.getElementById('fetch-items-button').addEventListener('click', () => {
        fetchItemsForPage(currentPage);
    });

    // 添加翻页按钮
    const paginationContainer = document.createElement('div');
    const nextButton = document.createElement('button');
    nextButton.innerText = '下一页';
    nextButton.addEventListener('click', () => {
        currentPage++;
        fetchItemsForPage(currentPage);
    });

    paginationContainer.appendChild(nextButton);
    document.body.appendChild(paginationContainer);
});

function fetchItemsForPage(page) {
    const itemsUrl = `https://thor.weidian.com/pyxis/pyxis.mysteryBoxRecordList/1.0?param={"auth":"mysteryBoxCenter","flowAction":"mystery_box_list_V2","page":${page},"limit":20}&wdtoken=${wdtoken}&_=${underscoreParams['_']}`;
    ipcRenderer.send('fetch-item', itemsUrl);
}

ipcRenderer.on('items-fetched', (event, newResults) => {
    const currentResults = JSON.parse(localStorage.getItem('currentResults') || '[]');

    // 合并并基于 itemName 去重和计数
    const combinedResults = [...currentResults, ...newResults];
    const groupedResults = combinedResults.reduce((acc, item) => {
        if (!acc[item.name]) {
            acc[item.name] = { ...item, count: 0 };
        }
        acc[item.name].count += item.count || 1; // 增加计数
        return acc;
    }, {});

    const updatedResults = Object.values(groupedResults);
    localStorage.setItem('currentResults', JSON.stringify(updatedResults));
    displayItems(updatedResults);
});

function fetchAuthAndName(itemId, orderId, wdtoken, underscoreParams) {
    const url = `https://thor.weidian.com/pyxis/pyxis.mysteryBoxLotteryPageInfo/1.0?param={"auth":"mysteryBoxCenter","flowAction":"mystery_box_info_V2","itemId":"${itemId}","orderId":"${orderId}"}&wdtoken=${wdtoken}&_=${underscoreParams['_']}`;
    return new Promise((resolve, reject) => {
        ipcRenderer.send('fetch-auth-and-name', { url });

        ipcRenderer.once('auth-and-name-response', (event, { auth, name }) => {
            if (auth && name) {
                resolve({ auth, name });
            } else {
                reject(new Error('Failed to fetch auth and name'));
            }
        });
    });
}

// 更新 displayItems 函数以支持区域划分
async function displayItems(targetList) {
    const itemContainer = document.getElementById('item-container');
    itemContainer.innerHTML = ''; // 清空之前的内容

    // 根据 itemId 分组
    const groupedItems = targetList.reduce((acc, item) => {
        if (!acc[item.itemId]) {
            acc[item.itemId] = [];
        }
        acc[item.itemId].push(item);
        return acc;
    }, {});

    // 为每个 itemId 创建一个分区
    for (const [itemId, items] of Object.entries(groupedItems)) {
        const section = document.createElement('div');
        section.style.marginBottom = '20px';

        // 获取 auth 和 name
        const { auth, name } = await fetchAuthAndName(itemId, items[0].orderId, wdtoken, underscoreParams);

        const title = document.createElement('h3');
        title.innerText = `盲盒名称: ${name})`;
        // title.innerText = `Item ID: ${itemId} (Auth: ${auth}, Name: ${name})`;
        section.appendChild(title);

        const table = document.createElement('table');
        table.style.width = '100%';
        table.setAttribute('border', '1');

        const thead = document.createElement('thead');
        const headerRow = document.createElement('tr');
        const headers = ['Item Name', 'Count'];
        headers.forEach(headerText => {
            const th = document.createElement('th');
            th.appendChild(document.createTextNode(headerText));
            headerRow.appendChild(th);
        });
        thead.appendChild(headerRow);
        table.appendChild(thead);

        const tbody = document.createElement('tbody');
        const itemDict = items.reduce((acc, item) => {
            if (!acc[item.name]) {
                acc[item.name] = { ...item, count: 0 };
            }
            acc[item.name].count += item.count || 1;
            return acc;
        }, {});

        for (const [itemName, item] of Object.entries(itemDict)) {
            const row = document.createElement('tr');
            const nameCell = document.createElement('td');
            nameCell.appendChild(document.createTextNode(itemName));
            const countCell = document.createElement('td');
            countCell.appendChild(document.createTextNode(item.count));

            row.appendChild(nameCell);
            row.appendChild(countCell);
            tbody.appendChild(row);
        }

        table.appendChild(tbody);
        section.appendChild(table);
         // Fetch complete list and calculate missing items
         const completeList = await fetchCompleteList(auth);
         const obtainedItems = items.map(item => item.name);
         const totalObtained = obtainedItems.length;
         const missingItems = completeList.filter(item => !obtainedItems.includes(item));
 
         // Display additional information
         const infoDiv = document.createElement('div');
         infoDiv.innerHTML = `
             <p>Total Obtained: ${totalObtained}</p>
             <p>Missing Items: ${missingItems.join(', ')}</p>
         `;
         section.appendChild(infoDiv);

        itemContainer.appendChild(section);
    }
    // 调用 processGroups 处理每个分组
    processGroups(groupedItems);
}

async function fetchCompleteList(auth) {
    try {
        const completeList = await ipcRenderer.invoke('get-complete-list', auth);
        return completeList;
    } catch (error) {
        console.error('Error fetching complete list:', error);
        return [];
    }
}

async function processGroups(groupedItems) {
    for (const [itemId, items] of Object.entries(groupedItems)) {
        const { auth, name } = await fetchAuthAndName(itemId, items[0].orderId, wdtoken, underscoreParams);

        // Fetch complete list from main process
        const completeList = await fetchCompleteList(auth);

        const obtainedItems = items.map(item => item.name);
        const totalObtained = obtainedItems.length;
        const missingItems = completeList.filter(item => !obtainedItems.includes(item));

        console.log(`Item ID: ${itemId} (Auth: ${auth}, Name: ${name})`);
        console.log(`Total Obtained: ${totalObtained}`);
        console.log(`Missing Items: ${missingItems.join(', ')}`);
    }
}