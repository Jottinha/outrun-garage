# Outrun Garage

Sistema de garagem standalone para QBCore, focado em servidores de corrida.
Veículos são gratuitos — sem dependência de qb-banking ou qb-vehicleshop.

## Instalação

1. Copie a pasta `outrun-garage` para `resources/`
2. Adicione no `server.cfg` (após qb-core e oxmysql):
   ```
   ensure outrun-garage
   ```
3. Reinicie o servidor

A tabela `player_vehicles` já existe no QBCore — nenhuma migração necessária.

## Configuração

Edite `config.lua`:

| Parâmetro | Descrição | Padrão |
|-----------|-----------|--------|
| `Config.Command` | Comando para abrir a garagem | `'garage'` |
| `Config.MaxVehiclesPerPlayer` | Limite de veículos por jogador | `5` |
| `Config.DefaultGarage` | Nome da garagem no DB | `'outrun'` |
| `Config.PlatePrefix` | Prefixo das placas (máx 3 chars) | `'OUT'` |
| `Config.PreviewLocation` | Coordenadas do local de customização | LSIA |
| `Config.UseRoutingBucket` | Isolamento no preview | `true` |
| `Config.AllowedVehicles` | Lista de modelos disponíveis | 10 carros |
| `Config.Colors` | Paleta de cores para tuning | ~50 cores |
| `Config.WindowTints` | Películas disponíveis | 6 opções |
| `Config.WheelTypes` | Tipos de roda | 11 tipos |

## Funcionalidades

- **`/garage`** — abre o menu principal
- **Pegar Veículo** — escolha entre os modelos permitidos (gratuito)
- **Customizar** — preview isolado com tuning completo:
  - Motor, freios, transmissão, suspensão, blindagem
  - Turbo e faróis xenon
  - Cor primária e secundária
  - Tipo e modelo de roda
  - Película de vidro
- **Salvar** — persiste todas as modificações no banco
- **Remover** — apaga o veículo da garagem

## Segurança (Anti-Exploit)

- Server valida ownership (citizenid + plate) em toda operação
- Modelo validado contra whitelist do config
- Rate limiting: aquisição (5s), salvamento (2s), remoção (5s)
- Limite máximo de veículos por jogador
- Placa gerada server-side com verificação de unicidade

## Como Testar

- [ ] `/garage` sem carros → clicar "Pegar Veículo" → escolher modelo → veículo aparece na lista
- [ ] `/garage` com carros → lista correta com nome, modelo e placa
- [ ] Customizar → alterar cor/mods → Salvar → reconectar → mods persistem no preview
- [ ] Jogador B não consegue salvar mods no carro do jogador A
- [ ] Limite de veículos respeitado (`Config.MaxVehiclesPerPlayer`)
- [ ] Placa gerada com prefixo correto (`Config.PlatePrefix`)
- [ ] ESC fecha o menu / cancela customização

## Dependências

- **qb-core** (obrigatório)
- **oxmysql** (obrigatório)

**Não requer:** qb-garages, qb-banking, qb-vehicleshop, qb-customs

## Integração Futura com Outrun

> **Nota:** Nenhum arquivo do Outrun foi modificado nesta entrega.
> A integração fica para um próximo passo — aqui estão os exports prontos.

### Exports Disponíveis (server-side)

#### `GetPlayerVehicles(citizenid)`

Retorna todos os veículos de um jogador na garagem outrun.

```lua
local vehicles = exports['outrun-garage']:GetPlayerVehicles(citizenid)
--[[
Retorna:
{
    { model = 'adder', label = 'Adder', plate = 'OUT1A2B3', mods = {...} },
    { model = 'sultan', label = 'Sultan', plate = 'OUTX9Y8Z', mods = {...} },
}
]]
```

#### `GetVehicleMods(citizenid, plate)`

Retorna as propriedades (mods) de um veículo específico.
Tabela compatível com `QBCore.Functions.SetVehicleProperties`.

```lua
local props = exports['outrun-garage']:GetVehicleMods(citizenid, plate)
-- Retorna: tabela de propriedades ou nil se não encontrado
```

### Exemplo de Spawn com Mods no Outrun

```lua
-- SERVER (outrun) — obter props do veículo salvo:
local citizenid = Player.PlayerData.citizenid
local plate = 'OUT1A2B3' -- placa escolhida pelo jogador
local props = exports['outrun-garage']:GetVehicleMods(citizenid, plate)

-- CLIENT (outrun) — após criar o veículo para a corrida:
-- (receber props via evento do server)
local vehicle = CreateVehicle(hash, x, y, z, heading, true, false)

if props then
    QBCore.Functions.SetVehicleProperties(vehicle, props)
end
-- O veículo agora tem todas as modificações salvas na garagem
```

Este snippet mostra como o Outrun pode spawnar veículos com as modificações
do jogador sem precisar modificar o resource outrun-garage.
