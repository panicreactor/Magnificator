# Magnificator

Мінімалістичний VST3 / AU / Standalone плагін «одна ручка» для швидкого
підмішування реверберації з контрольованою «тональною вагою».

> **🚀 Хочете готовий `.vst3` для Windows не встановлюючи нічого локально?**
> Читайте **[HOW_TO_BUILD_ON_GITHUB.md](HOW_TO_BUILD_ON_GITHUB.md)** —
> білд в хмарі GitHub через `.github/workflows/build-windows.yml`,
> готовий файл завантажите з вкладки Actions за ~5 хвилин.

> **Концепція.** Крутиш одну велику ручку (**Magnify**) — і одразу отримуєш
> три ефекти в каскаді:
> 1. **High-shelf** на ~4 кГц (зрізає верхи, до **−18 дБ** на максимумі)
> 2. **Bell @ 250 Гц** (виймає mud, до **−9 дБ** на максимумі)
> 3. Домішується **tail-only реверб** (без ранніх віддзеркалень, без predelay)
>
> Тип реверба (Room / Hall / Chamber / Spring) обирається в окремому вікні.

---

## Структура проєкту

```
Magnificator/
├── CMakeLists.txt
├── README.md
└── Source/
    ├── PluginProcessor.h / .cpp        ← AudioProcessor + APVTS
    ├── PluginEditor.h / .cpp           ← головне вікно, scale S/M/L
    ├── DSP/
    │   ├── FilterChain.h / .cpp        ← high-shelf + bell @ 250Hz
    │   └── ReverbEngine.h / .cpp       ← Freeverb (Room/Hall/Chamber) + кастомний Spring
    └── GUI/
        ├── MagnificatorLookAndFeel.h / .cpp  ← тема (Material-inspired)
        ├── BigKnob.h / .cpp                  ← круглий knob + glow-анімація
        └── ReverbSelectorWindow.h / .cpp     ← окреме вікно вибору типу
```

---

## Параметри (APVTS)

| ID         | Тип    | Діапазон           | Призначення                              |
|------------|--------|--------------------|------------------------------------------|
| `magnify`  | float  | 0.0 ..  1.0        | Головна ручка (глибина EQ + wet mix)    |
| `drywet`   | float  | 0.0 ..  1.0        | Стеля «мокрого» рівня                    |
| `revtype`  | choice | 0..3               | Room / Hall / Chamber / Spring           |
| `uisize`   | choice | 0..2               | UI size: Small / Medium / Large          |

Формула wet gain: `wetGain = drywet × magnify`. Це дає звичну поведінку:
при `magnify = 0` плагін прозорий, при повному повороті домішується реверб
до стелі, заданої ручкою Dry/Wet.

---

## Побудова плагіна

### 1. Передумови

* **CMake ≥ 3.22**
* **C++17 компілятор**: MSVC 2019+, Clang 10+, GCC 9+, Apple Clang
* **Git** (для клонування JUCE)

На Linux потрібні системні бібліотеки JUCE:
```bash
sudo apt install libasound2-dev libjack-jackd2-dev \
    ladspa-sdk libcurl4-openssl-dev libfreetype6-dev \
    libx11-dev libxcomposite-dev libxcursor-dev libxcursor-dev \
    libxext-dev libxinerama-dev libxrandr-dev libxrender-dev \
    libwebkit2gtk-4.0-dev libglu1-mesa-dev mesa-common-dev
```

### 2. Клонуємо JUCE усередину проєкту

```bash
cd Magnificator
git clone --depth 1 --branch 7.0.12 https://github.com/juce-framework/JUCE.git
```

### 3. Конфігуруємо і збираємо

```bash
cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build --config Release -j
```

### 4. Куди встановлюється

`COPY_PLUGIN_AFTER_BUILD=TRUE` в `CMakeLists.txt` автоматично копіює VST3 / AU
у системні теки після збірки:

| ОС       | VST3                                       | AU                                   |
|----------|--------------------------------------------|--------------------------------------|
| macOS    | `~/Library/Audio/Plug-Ins/VST3/`           | `~/Library/Audio/Plug-Ins/Components/` |
| Windows  | `C:\Program Files\Common Files\VST3\`      | —                                    |
| Linux    | `~/.vst3/`                                 | —                                    |

Standalone бінарник — у `build/Magnificator_artefacts/Release/Standalone/`.

---

## DSP архітектура

```
audio in ──► [High-shelf 4 kHz]  ──► [Bell 250 Hz]  ──┬──► dry path ──►┐
                ↑                       ↑             │                 │
                │                       │             └─► [Reverb] ──►  +──► out
                │                       │                                ↑
             magnify × −18 dB     magnify × −9 dB                   magnify × drywet
```

### Фільтри
* **High-shelf**: Q = 0.707 (м'який, без резонансу), крива
  `gain = −18 dB × magnify^0.7`.
* **Bell**: Q = 1.0, крива `gain = −9 dB × magnify^0.85`.

Експоненти підібрані так, щоб ефект був відчутний **уже на початку** ходу
ручки, а не тільки на останніх 20%.

### Реверб
* **Room / Hall / Chamber** — JUCE `dsp::Reverb` (Freeverb). У цієї
  архітектури немає окремої секції early reflections, тому «tail-only»
  виходить природно. `dryLevel = 0`, `wetLevel = 1` — сухий підмішує
  ProcessBlock вручну.
* **Spring** — власна імплементація:
  * каскад **6 allpass** із зростаючими часами (4.7 / 7.3 / 11.1 / 13.8 / 17.5 / 21.9 мс)
    і спадними коефіцієнтами (0.72 → 0.62) — дає характерну **дисперсію**,
    з якою високі частоти в пружині «відстають»;
  * **модульована delay-line** (LFO ~0.7 Гц, база 45 мс, глибина ±2.5 мс);
  * **демпфер** у петлі feedback — приглушує верхи з кожним колом.

Щоб замінити Freeverb на щось серйозніше (FDN, schroeder-moorer із 8
пізніх дифузорів, convolution на IR-и) — патч робиться тільки у
`ReverbEngine.cpp` без дотиків до іншого коду.

---

## GUI

### Big Knob
`BigKnob` успадковує `juce::Component` напряму (не Slider) — це дає повний
контроль над рендером. Склад промальовки:

1. Radial glow (alpha пропорційна згладженому значенню)
2. Track arc (неактивна частина)
3. Active arc (акцентний колір)
4. Тіло knob із radial gradient
5. Внутрішнє «вікно» з лінійним градієнтом
6. Pointer (яскравість зростає з magnify)
7. Відсотковий індикатор у центрі

**Таймер 30 Гц**, repaint викликається **тільки коли displayValue
змінився помітно** (> 1e-3). Це дає плавну ekonomiчну анімацію,
вкладається в бюджет «≤ 25 % ресурсів GUI».

### Scale S/M/L
Розмір задається мультиплікатором (0.80× / 1.00× / 1.30×) від базової
сітки 440 × 380. Усі дочірні компоненти використовують `juce::Rectangle`
арифметику в `resized()`, тож пропорції зберігаються точно.

### Reverb Selector
Окреме `DocumentWindow` (`ReverbSelectorWindow`), що відкривається/
закривається повторним натисканням кнопки. Сітка 2×2 із RadioGroup-подібною
поведінкою; вибір пишеться напряму в APVTS.

---

## Що легко покращити далі

* Замінити `makeHighShelf` / `makePeakFilter` на ручне обчислення
  коефіцієнтів без алокацій (для справжньої RT-safety).
* Додати **oversampling × 2** на EQ-блоці (JUCE `dsp::Oversampling`) —
  уникнути aliasing на крутих shelf-кривих.
* Написати **FDN** замість Freeverb (Stautner–Puckette, 8 × 8 Hadamard mix).
* Додати **modulated delay taps** для модерн-звучання Hall.
* Зберегти UI-size поза APVTS (не як автоматизований параметр).

---

## Ліцензія

Код MIT. JUCE постачається окремо під власною ліцензією —
комерційне використання потребує JUCE Pro/Indie ліцензії.
