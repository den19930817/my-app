'use strict';
const names = ['Понедельник', 'Вторник', 'Среда', 'Четверг', 'Пятница', 'Суббота', 'Воскресенье'];
const shortNames = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
const key = 'training-plan-v1';
const sample = () => [
  [{name:'Приседания',sets:3,reps:'12 повторений',done:false},{name:'Отжимания',sets:3,reps:'10 повторений',done:false},{name:'Планка',sets:3,reps:'30 секунд',done:false}],
  [], [{name:'Выпады',sets:3,reps:'10 на каждую ногу',done:false},{name:'Ягодичный мост',sets:3,reps:'15 повторений',done:false}], [],
  [{name:'Приседания',sets:3,reps:'12 повторений',done:false},{name:'Планка',sets:3,reps:'30 секунд',done:false}], [], []
];
let plan = sample();
const $ = id => document.getElementById(id);
try {
  const saved = localStorage.getItem(key);
  if (saved) {
    const data = JSON.parse(saved);
    if (!Array.isArray(data) || data.length !== 7 || !data.every(day => Array.isArray(day) && day.every(e => e && typeof e.name === 'string' && Number.isInteger(e.sets) && e.sets > 0 && e.sets <= 99 && typeof e.reps === 'string' && typeof e.done === 'boolean'))) throw new Error('Invalid plan');
    plan = data;
  }
} catch { $('notice').textContent = 'Не удалось прочитать сохранённый план. Показан пример; новые изменения попробуем сохранить.'; }
let selected = (new Date().getDay() + 6) % 7;
function save() {
  try {localStorage.setItem(key, JSON.stringify(plan)); $('notice').textContent = '';}
  catch {$('notice').textContent = 'Браузер не разрешил сохранение. Изменения доступны до закрытия страницы.';}
}
function render() {
  $('days').replaceChildren();
  shortNames.forEach((name, i) => {
    const button = document.createElement('button');
    button.className = 'day' + (i === selected ? ' active' : '');
    button.textContent = name; button.setAttribute('aria-pressed', String(i === selected));
    button.setAttribute('aria-label', names[i]);
    button.onclick = () => {selected = i; render();};
    $('days').append(button);
  });
  $('daytitle').textContent = names[selected];
  $('exercises').replaceChildren();
  if (!plan[selected].length) {
    const p = document.createElement('p'); p.className = 'empty'; p.textContent = 'День для восстановления. Или добавь свою тренировку.'; $('exercises').append(p);
  }
  plan[selected].forEach((exercise, i) => {
    const row = document.createElement('div'); row.className = 'exercise' + (exercise.done ? ' done' : '');
    const checkbox = document.createElement('input'); checkbox.type = 'checkbox'; checkbox.id = 'exercise-' + i; checkbox.checked = exercise.done;
    checkbox.onchange = () => {exercise.done = checkbox.checked; save(); render(); document.getElementById('exercise-' + i)?.focus();};
    const label = document.createElement('label'); label.htmlFor = checkbox.id;
    const title = document.createElement('strong'); title.textContent = exercise.name;
    const detail = document.createElement('small'); detail.textContent = exercise.sets + ' подх. · ' + exercise.reps; label.append(title, detail);
    const remove = document.createElement('button'); remove.className = 'remove'; remove.textContent = '×'; remove.setAttribute('aria-label', 'Удалить: ' + exercise.name);
    remove.onclick = () => {if (confirm('Удалить упражнение «' + exercise.name + '»?')) {plan[selected].splice(i,1); save(); render();}};
    row.append(checkbox, label, remove); $('exercises').append(row);
  });
  const all = plan.flat(), done = all.filter(e => e.done).length, percent = all.length ? Math.round(done / all.length * 100) : 0;
  $('sessions').textContent = plan.filter(d => d.length).length;
  $('completed').textContent = done + ' / ' + all.length; $('percent').textContent = percent + '%';
  $('progress').textContent = done ? 'Уже выполнено ' + done + ' из ' + all.length + ' упражнений. Продолжай в своём темпе.' : 'Твой следующий шаг — первая отметка в плане.';
  $('bar').style.width = percent + '%';
}
function openForm() {$('form').reset(); $('dialog').showModal(); $('name').focus();}
$('new').onclick = openForm; $('add').onclick = openForm; $('cancel').onclick = () => $('dialog').close();
$('form').onsubmit = event => {
  event.preventDefault(); const name = $('name').value.trim(), reps = $('reps').value.trim();
  if (!name || !reps) return;
  plan[selected].push({name, sets:Number($('sets').value), reps, done:false}); save(); render(); $('dialog').close();
};
render();
