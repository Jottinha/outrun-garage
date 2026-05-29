(function () {
    'use strict';

    var currentVehicles = [];
    var allowedVehicles = [];
    var maxVehicles = 5;
    var currentCategories = [];
    var selectedCategoryIndex = -1;

    var resourceName = typeof GetParentResourceName !== 'undefined' ? GetParentResourceName() : 'outrun-garage';

    function post(event, data) {
        return fetch('https://' + resourceName + '/' + event, {
            method: 'POST',
            headers: {'Content-Type': 'application/json'},
            body: JSON.stringify(data || {}),
        });
    }

    function escapeHtml(text) {
        var d = document.createElement('div');
        d.textContent = text || '';
        return d.innerHTML;
    }

    // ==================== Event Listeners ====================

    document.getElementById('btn-close').addEventListener('click', function () { post('closeMenu'); });
    document.getElementById('btn-get-vehicle').addEventListener('click', showPicker);
    document.getElementById('btn-back').addEventListener('click', showMenu);
    document.getElementById('btn-save').addEventListener('click', function () { post('saveCustomize'); });
    document.getElementById('btn-cancel').addEventListener('click', function () { post('cancelCustomize'); });

    document.addEventListener('keydown', function (e) {
        if (e.key === 'Escape') {
            var app = document.getElementById('app');
            if (app.style.display === 'none') return;
            var customize = document.getElementById('customize-menu');
            if (customize.style.display !== 'none') {
                post('cancelCustomize');
            } else {
                post('closeMenu');
            }
        }
    });

    // ==================== NUI Messages ====================

    window.addEventListener('message', function (event) {
        var data = event.data;
        switch (data.action) {
            case 'openMenu':
                currentVehicles = data.vehicles || [];
                allowedVehicles = data.allowedVehicles || [];
                maxVehicles = data.maxVehicles || 5;
                showMainMenu();
                break;
            case 'openCustomize':
                showCustomize(data.categories);
                updateStats(data.stats);
                break;
            case 'updateStats':
                updateStats(data.stats);
                break;
            case 'updateWheelOptions':
                updateWheelOptions(data.options);
                break;
            case 'closeAll':
                closeAll();
                break;
        }
    });

    // ==================== Views ====================

    function showMainMenu() {
        document.getElementById('app').style.display = 'flex';
        document.getElementById('garage-menu').style.display = 'flex';
        document.getElementById('vehicle-picker').style.display = 'none';
        document.getElementById('customize-menu').style.display = 'none';
        renderVehicleList();
    }

    function renderVehicleList() {
        var list = document.getElementById('vehicle-list');
        var noVehicles = document.getElementById('no-vehicles');
        var btnGet = document.getElementById('btn-get-vehicle');
        var countEl = document.getElementById('vehicle-count');

        list.innerHTML = '';

        if (currentVehicles.length === 0) {
            noVehicles.style.display = 'block';
        } else {
            noVehicles.style.display = 'none';
            currentVehicles.forEach(function (v, idx) {
                var card = document.createElement('div');
                card.className = 'vehicle-card';
                card.innerHTML =
                    '<div class="vehicle-info">' +
                        '<h3>' + escapeHtml(v.label || v.model) + '</h3>' +
                        '<span class="plate">' + escapeHtml(v.plate) + '</span>' +
                    '</div>' +
                    '<div class="vehicle-actions">' +
                        '<button class="btn-sm btn-customize" data-action="customize" data-index="' + idx + '">CUSTOMIZAR</button>' +
                        '<button class="btn-sm btn-delete" data-action="delete" data-index="' + idx + '">X</button>' +
                    '</div>';
                list.appendChild(card);
            });
        }

        countEl.textContent = currentVehicles.length + '/' + maxVehicles;
        btnGet.disabled = currentVehicles.length >= maxVehicles;
        btnGet.textContent = currentVehicles.length >= maxVehicles ? 'LIMITE ATINGIDO' : '+ PEGAR VEÍCULO';

        list.onclick = function (e) {
            var btn = e.target.closest('[data-action]');
            if (!btn) return;
            var idx = parseInt(btn.dataset.index);
            var vehicle = currentVehicles[idx];
            if (!vehicle) return;

            if (btn.dataset.action === 'customize') {
                post('customizeVehicle', {plate: vehicle.plate, model: vehicle.model, mods: vehicle.mods});
            } else if (btn.dataset.action === 'delete') {
                post('deleteVehicle', {plate: vehicle.plate});
            }
        };
    }

    function showPicker() {
        document.getElementById('garage-menu').style.display = 'none';
        document.getElementById('vehicle-picker').style.display = 'flex';

        var pickerList = document.getElementById('picker-list');
        pickerList.innerHTML = '';

        allowedVehicles.forEach(function (v) {
            var card = document.createElement('div');
            card.className = 'picker-card';
            card.innerHTML =
                '<h4>' + escapeHtml(v.label) + '</h4>' +
                '<span class="model">' + escapeHtml(v.model) + '</span>';
            card.addEventListener('click', function () {
                if (card.classList.contains('disabled')) return;
                card.classList.add('disabled');
                post('acquireVehicle', {model: v.model});
            });
            pickerList.appendChild(card);
        });
    }

    function showMenu() {
        document.getElementById('vehicle-picker').style.display = 'none';
        document.getElementById('garage-menu').style.display = 'flex';
    }

    // ==================== Customização ====================

    function showCustomize(categories) {
        currentCategories = categories;
        selectedCategoryIndex = -1;

        document.getElementById('app').style.display = 'flex';
        document.getElementById('garage-menu').style.display = 'none';
        document.getElementById('vehicle-picker').style.display = 'none';
        document.getElementById('customize-menu').style.display = 'flex';

        renderCategories();
        document.getElementById('options-panel').innerHTML = '<p class="options-hint">Selecione uma categoria</p>';
    }

    function renderCategories() {
        var catList = document.getElementById('category-list');
        catList.innerHTML = '';

        currentCategories.forEach(function (cat, idx) {
            var btn = document.createElement('button');
            btn.className = 'category-btn' + (idx === selectedCategoryIndex ? ' active' : '');
            btn.textContent = cat.label;
            btn.addEventListener('click', function () {
                selectedCategoryIndex = idx;
                renderCategories();
                renderOptions(cat);
            });
            catList.appendChild(btn);
        });
    }

    function renderOptions(category) {
        var panel = document.getElementById('options-panel');
        panel.innerHTML = '';

        if (category.type === 'mod') {
            renderModOptions(panel, category);
        } else if (category.type === 'color') {
            renderColorOptions(panel, category);
        } else if (category.type === 'toggle') {
            renderToggle(panel, category);
        } else if (category.type === 'wheelType') {
            renderWheelType(panel, category);
        } else if (category.type === 'tint') {
            renderTintOptions(panel, category);
        }
    }

    function renderModOptions(panel, category) {
        category.options.forEach(function (opt) {
            var btn = document.createElement('button');
            btn.className = 'option-btn' + (opt.selected ? ' selected' : '');
            btn.textContent = opt.label;
            btn.addEventListener('click', function () {
                panel.querySelectorAll('.option-btn').forEach(function (b) { b.classList.remove('selected'); });
                btn.classList.add('selected');
                category.options.forEach(function (o) { o.selected = false; });
                opt.selected = true;
                post('applyMod', {modType: category.modType, index: opt.index});
            });
            panel.appendChild(btn);
        });
    }

    function renderColorOptions(panel, category) {
        var grid = document.createElement('div');
        grid.className = 'color-grid';

        category.options.forEach(function (color) {
            var swatch = document.createElement('div');
            swatch.className = 'color-swatch' + (color.id === category.currentColor ? ' selected' : '');
            swatch.style.backgroundColor = color.hex;
            swatch.title = color.name;
            swatch.addEventListener('click', function () {
                grid.querySelectorAll('.color-swatch').forEach(function (s) { s.classList.remove('selected'); });
                swatch.classList.add('selected');
                category.currentColor = color.id;
                post('applyColor', {target: category.target, colorId: color.id});
            });
            grid.appendChild(swatch);
        });

        panel.appendChild(grid);
    }

    function renderToggle(panel, category) {
        var container = document.createElement('div');
        container.className = 'toggle-container';

        var label = document.createElement('span');
        label.className = 'toggle-label';
        label.textContent = category.enabled ? 'Ativado' : 'Desativado';

        var toggle = document.createElement('div');
        toggle.className = 'toggle-switch' + (category.enabled ? ' on' : '');
        toggle.addEventListener('click', function () {
            category.enabled = !category.enabled;
            toggle.classList.toggle('on');
            label.textContent = category.enabled ? 'Ativado' : 'Desativado';
            post('applyToggle', {modType: category.modType, enabled: category.enabled});
        });

        container.appendChild(label);
        container.appendChild(toggle);
        panel.appendChild(container);
    }

    function renderWheelType(panel, category) {
        category.options.forEach(function (wt) {
            var btn = document.createElement('button');
            btn.className = 'option-btn' + (wt.id === category.currentType ? ' selected' : '');
            btn.textContent = wt.name;
            btn.addEventListener('click', function () {
                panel.querySelectorAll('.option-btn').forEach(function (b) { b.classList.remove('selected'); });
                btn.classList.add('selected');
                category.currentType = wt.id;
                post('applyWheelType', {wheelType: wt.id});
            });
            panel.appendChild(btn);
        });
    }

    function renderTintOptions(panel, category) {
        category.options.forEach(function (t) {
            var btn = document.createElement('button');
            btn.className = 'option-btn' + (t.id === category.currentTint ? ' selected' : '');
            btn.textContent = t.name;
            btn.addEventListener('click', function () {
                panel.querySelectorAll('.option-btn').forEach(function (b) { b.classList.remove('selected'); });
                btn.classList.add('selected');
                category.currentTint = t.id;
                post('applyTint', {tintId: t.id});
            });
            panel.appendChild(btn);
        });
    }

    function setBar(key, val) {
        val = Math.max(0, Math.min(100, val || 0));
        var fill = document.getElementById('stat-' + key);
        var lbl = document.getElementById('stat-' + key + '-val');
        if (fill) fill.style.width = val + '%';
        if (lbl) lbl.textContent = val + '%';
    }

    function updateStats(stats) {
        if (!stats) return;
        setBar('speed', stats.speed);
        // Velocidade mostra o km/h real ao lado da barra (não a %)
        var speedLbl = document.getElementById('stat-speed-val');
        if (speedLbl && typeof stats.speedKmh !== 'undefined') {
            speedLbl.textContent = stats.speedKmh + ' km/h';
        }
        setBar('accel', stats.accel);
        setBar('braking', stats.braking);
        setBar('traction', stats.traction);
    }

    function updateWheelOptions(options) {
        for (var i = 0; i < currentCategories.length; i++) {
            if (currentCategories[i].id === 'wheelIndex') {
                currentCategories[i].options = options;
                if (selectedCategoryIndex === i) {
                    renderOptions(currentCategories[i]);
                }
                break;
            }
        }
    }

    function closeAll() {
        document.getElementById('app').style.display = 'none';
        document.getElementById('garage-menu').style.display = 'none';
        document.getElementById('vehicle-picker').style.display = 'none';
        document.getElementById('customize-menu').style.display = 'none';
        isDragging = false;
    }

    // Drag para rotacionar câmera 360° (clica e arrasta fora do painel)
    var isDragging = false;
    var lastMouseX = 0;

    document.addEventListener('mousedown', function (e) {
        if (document.getElementById('customize-menu').style.display === 'none') return;
        if (e.target.closest('.customize-panel')) return;
        isDragging = true;
        lastMouseX = e.clientX;
        document.body.style.cursor = 'grabbing';
    });

    document.addEventListener('mousemove', function (e) {
        if (!isDragging) return;
        var deltaX = e.clientX - lastMouseX;
        lastMouseX = e.clientX;
        if (deltaX !== 0) {
            post('rotateCam', {deltaX: deltaX});
        }
    });

    document.addEventListener('mouseup', function () {
        if (isDragging) {
            isDragging = false;
            document.body.style.cursor = '';
        }
    });

})();
