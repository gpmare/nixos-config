// Idempotent: adds compact CPU/RAM/GPU text widgets to the tray panel and
// (re)applies short labels on existing ones. Never touches the system tray.
// Labels live in [Configuration][SensorLabels] as plain key=value (not JSON).
const want = [["cpu/all/usage","CPU"],["memory/physical/usedPercent","RAM"],["gpu/all/usage","GPU"]];
function label(w, id, name) {
  w.currentConfigGroup = ["Appearance"];
  w.writeConfig("chartFace","org.kde.ksysguard.textonly");
  w.writeConfig("title",name);
  w.writeConfig("showTitle",true);
  w.currentConfigGroup = ["Sensors"];
  w.writeConfig("highPrioritySensorIds", JSON.stringify([id]));
  w.currentConfigGroup = ["SensorLabels"];
  w.writeConfig(id, name);
}
panels().forEach(p => {
  if (!p.widgets().some(w => w.type == "org.kde.plasma.systemtray")) return;
  const existing = p.widgets("org.kde.plasma.systemmonitor");
  const added = [];
  want.forEach(([id,name]) => {
    let w = existing.find(x => { x.currentConfigGroup=["Sensors"]; return String(x.readConfig("highPrioritySensorIds","")).indexOf(id) >= 0; });
    if (!w) { w = p.addWidget("org.kde.plasma.systemmonitor"); added.push(w.id); }
    label(w, id, name);
  });
  if (!added.length) return;
  p.currentConfigGroup = ["General"];
  let order = String(p.readConfig("AppletOrder","")).split(";").filter(x=>x);
  if (!order.length) order = p.widgets().map(w=>String(w.id));
  order = order.filter(x => added.map(String).indexOf(x) < 0);
  const tray = p.widgets("org.kde.plasma.systemtray")[0];
  let i = order.indexOf(String(tray.id)); if (i < 0) i = order.length;
  order.splice(i, 0, ...added.map(String));
  p.writeConfig("AppletOrder", order.join(";"));
  p.reloadConfig && p.reloadConfig();
});
