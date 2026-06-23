export function spec() {
  return [
    {
      type: "function",
      function: {
        name: "get_unit_alarms",
        description: "Retrieve list of alarms for one or more units. If no unit names are given, returns all alarms",
        parameters: {
          type: "object",
          "properties": {
            units: {
              type: "array",
              items: { type: "string" },
              description: "List of unit names"
            }
          },
          required: ["units"]
        }
      }
    },

    {
      "type": "function",
      "function": {
        "name": "geo_search_units",
        "description": "Search for units by location",
        "parameters": {
          type: "object",
          "properties": {
            location: {
              "type": "string",
              "description": "Location"                  
            }
          },
          required: ["location"]
        }
      }
    }
  ]
}

export async function toolHandler(name, args) {
  if (name == "get_unit_alarms") {
    return await get_unit_alarms(args);
  }

  throw new Error(`Invalid tool call: ${name}`);
}

async function get_unit_alarms({ units }) {
  const alarms = [];
  const all = units.length == 0;
  if (all || (units.indexOf('/icex1') >= 0)) {
    alarms.push({
      path: '/icex1/a1',
      description: 'High pressure in unit 1'
    });
    alarms.push({
      path: '/icex1/a2',
      description: 'High temperature in unit 1'
    });
  }
  if (all || (units.indexOf('/icex2') >= 0)) {
    alarms.push({
      path: '/icex2/a3',
      description: 'Low pressure in unit 2'
    });
    alarms.push({
      path: '/icex2/a4',
      description: 'Low temperature in unit 2'
    });
  }
  return alarms;
}
