const want = [["cpu/all/usage","CPU"],["memory/physical/usedPercent","RAM"],["gpu/all/usage","GPU"]];
panels().forEach(p => {
  if (!p.widgets().some(w => w.type == "org.kde.plasma.systemtray")) return;
  const have = p.widgets("org.kde.plasma.systemmonitor").map(w => { w.currentConfigGroup=["Sensors"]; return w.readConfig("highPrioritySensorIds",""); }).join(" ");
  const added = [];
  want.forEach(([id,title]) => {
    if (have.indexOf(id) >= 0) return;
    const w = p.addWidget("org.kde.plasma.systemmonitor");
    w.currentConfigGroup = ["Appearance"];
    w.writeConfig("chartFace","org.kde.ksysguard.textonly");
    w.writeConfig("title",title);
    w.writeConfig("showTitle",true);
    w.currentConfigGroup = ["Sensors"];
    w.writeConfig("highPrioritySensorIds", JSON.stringify([id]));
    added.push(w.id);
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
