Config = {}

-- Comando para abrir a garagem
Config.Command = 'garage'

-- Tecla padrão para abrir a garagem (reconfigurável em Configurações > Teclas
-- do FiveM). Deixe '' para não registrar atalho.
Config.OpenKey = 'G'

-- Máximo de veículos por jogador
Config.MaxVehiclesPerPlayer = 5

-- Nome da garagem no banco de dados (coluna "garage" em player_vehicles)
Config.DefaultGarage = 'outrun'

-- Prefixo para geração de placas (máx 3 caracteres, total sempre 8)
Config.PlatePrefix = 'OUT'

-- Local de preview para customização (vector4: x, y, z, heading)
-- Ponto interno do Auto Shop (DLC Tuner), sobre o elevador.
Config.PreviewLocation = vector4(-1328.17, 141.73, -99.19, 47.0)

-- Carregar o interior do Auto Shop (DLC Tuner) e fazer o preview lá dentro.
-- Requer bob74_ipl e game build >= 2372 (servidor está em 3095).
Config.UseAutoShop = true
Config.AutoShopInterior = 285953

-- Câmera do preview (ajuste fino do enquadramento no interior fechado)
Config.PreviewCam = {
    distance = 4.5, -- raio da órbita (menor para caber no Auto Shop)
    height   = 1.2, -- altura da câmera acima do carro
    lookZ    = 0.3, -- altura do ponto que a câmera mira
}

-- Usar routing bucket para isolar o jogador durante o preview
Config.UseRoutingBucket = true

-- Valores de referência para normalizar as barras de performance (0-100%).
-- As natives devolvem floats brutos; cada stat é dividido pelo seu "máximo"
-- aqui pra virar porcentagem. Calibre se quiser que os carros mais rápidos
-- batam perto de 100%.
--   speed    -> GetVehicleEstimatedMaxSpeed (em km/h, já convertido)
--   accel    -> GetVehicleAcceleration
--   braking  -> GetVehicleMaxBraking
--   traction -> GetVehicleMaxTraction
Config.PerfStats = {
    maxSpeed    = 210.0, -- km/h (teto da barra; acima do carro mais rápido)
    maxAccel    = 0.5,
    maxBraking  = 1.2,
    maxTraction = 2.6,
}

-- Top speed REAL (km/h) por modelo, medido em pista por Broughy1322 com o
-- carro totalmente upgradado. É o valor exibido em km/h ao lado da barra e
-- usado para o preenchimento dela. Fixo por modelo (no GTA o teto de
-- velocidade praticamente não muda com mods). Carros fora desta tabela caem
-- no fallback GetVehicleEstimatedMaxSpeed.
-- Fonte: gta5rides.com / gtacars.net (testes Broughy1322).
Config.TopSpeeds = {
    adder    = 200.8,
    zentorno = 196.3,
    t20      = 196.7,
    turismor = 195.9,
    entityxf = 195.5,
    comet2   = 192.3,
    elegy2   = 190.7,
    banshee  = 189.5,
    infernus = 189.5,
    sultan   = 186.3,
}

-- Veículos disponíveis para aquisição gratuita
Config.AllowedVehicles = {
    { model = 'adder',     label = 'Adder' },
    { model = 'zentorno',  label = 'Zentorno' },
    { model = 'sultan',    label = 'Sultan' },
    { model = 'elegy2',    label = 'Elegy RH8' },
    { model = 't20',       label = 'T20' },
    { model = 'turismor',  label = 'Turismo R' },
    { model = 'comet2',    label = 'Comet' },
    { model = 'banshee',   label = 'Banshee' },
    { model = 'infernus',  label = 'Infernus' },
    { model = 'entityxf',  label = 'Entity XF' },
}

-- Paleta de cores para customização (id = cor GTA, hex = aproximação para UI)
Config.Colors = {
    { id = 0,   name = 'Preto',             hex = '#0d1116' },
    { id = 1,   name = 'Grafite',           hex = '#1c1d21' },
    { id = 2,   name = 'Preto Aço',         hex = '#32383d' },
    { id = 3,   name = 'Prata Escuro',      hex = '#45484b' },
    { id = 4,   name = 'Prata',             hex = '#878787' },
    { id = 5,   name = 'Prata Azul',        hex = '#c2c4c6' },
    { id = 6,   name = 'Cinza Aço',         hex = '#979a97' },
    { id = 7,   name = 'Cinza Sombra',      hex = '#637380' },
    { id = 8,   name = 'Cinza Pedra',       hex = '#63625c' },
    { id = 9,   name = 'Cinza Meia-Noite',  hex = '#3c3f47' },
    { id = 10,  name = 'Cinza Arma',        hex = '#444e54' },
    { id = 12,  name = 'Preto Carbon',      hex = '#1c1c1c' },
    { id = 27,  name = 'Vermelho',          hex = '#c10000' },
    { id = 28,  name = 'Vermelho Torino',   hex = '#da0b00' },
    { id = 29,  name = 'Vermelho Fórmula',  hex = '#b40000' },
    { id = 30,  name = 'Vermelho Flama',    hex = '#8f1e00' },
    { id = 31,  name = 'Vermelho Gracioso', hex = '#730000' },
    { id = 35,  name = 'Vermelho Lava',     hex = '#b00000' },
    { id = 36,  name = 'Vermelho Deserto',  hex = '#703112' },
    { id = 38,  name = 'Laranja',           hex = '#f78616' },
    { id = 39,  name = 'Laranja Sunset',    hex = '#e96519' },
    { id = 41,  name = 'Laranja Ouro',      hex = '#c48e13' },
    { id = 42,  name = 'Amarelo Corrida',   hex = '#dae238' },
    { id = 43,  name = 'Amarelo',           hex = '#f5f542' },
    { id = 44,  name = 'Bronze',            hex = '#917332' },
    { id = 49,  name = 'Verde Escuro',      hex = '#132428' },
    { id = 50,  name = 'Verde Corrida',     hex = '#122e2b' },
    { id = 51,  name = 'Verde Mar',         hex = '#12383c' },
    { id = 53,  name = 'Verde Oliva',       hex = '#4b573a' },
    { id = 55,  name = 'Verde Lima',        hex = '#418c39' },
    { id = 61,  name = 'Azul Galaxy',       hex = '#222d5b' },
    { id = 62,  name = 'Azul Escuro',       hex = '#1f2852' },
    { id = 63,  name = 'Azul Saxony',       hex = '#253870' },
    { id = 64,  name = 'Azul',              hex = '#1c3551' },
    { id = 67,  name = 'Azul Marina',       hex = '#1c2f4f' },
    { id = 70,  name = 'Azul Ultra',        hex = '#2354a1' },
    { id = 73,  name = 'Ciano',             hex = '#2f8297' },
    { id = 88,  name = 'Verde Elétrico',    hex = '#bcff00' },
    { id = 111, name = 'Branco',            hex = '#f0f0f0' },
    { id = 112, name = 'Branco Frost',      hex = '#dadada' },
    { id = 120, name = 'Amarelo Taxi',      hex = '#f2c10f' },
    { id = 135, name = 'Rosa Quente',       hex = '#ff69b4' },
    { id = 138, name = 'Rosa Pink',         hex = '#ff1493' },
    { id = 141, name = 'Roxo',              hex = '#7b368a' },
    { id = 142, name = 'Roxo Escuro',       hex = '#4c2661' },
    { id = 145, name = 'Ouro',              hex = '#c2a251' },
    { id = 146, name = 'Ouro Escuro',       hex = '#916b1a' },
    { id = 158, name = 'Mate Preto',        hex = '#050505' },
    { id = 159, name = 'Mate Cinza',        hex = '#252527' },
}

-- Películas de vidro disponíveis
Config.WindowTints = {
    { id = 0, name = 'Nenhuma' },
    { id = 1, name = 'Preto Puro' },
    { id = 2, name = 'Escuro' },
    { id = 3, name = 'Claro' },
    { id = 4, name = 'Limousine' },
    { id = 5, name = 'Verde' },
}

-- Tipos de rodas disponíveis
Config.WheelTypes = {
    { id = 0,  name = 'Sport' },
    { id = 1,  name = 'Muscle' },
    { id = 2,  name = 'Lowrider' },
    { id = 3,  name = 'SUV' },
    { id = 4,  name = 'Off-Road' },
    { id = 5,  name = 'Tuner' },
    { id = 7,  name = 'High End' },
    { id = 8,  name = 'Bennys Original' },
    { id = 9,  name = 'Bennys Bespoke' },
    { id = 11, name = 'Street' },
    { id = 12, name = 'Track' },
}
