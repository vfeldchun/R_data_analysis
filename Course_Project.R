##########################################################################################################################################
# Курсовой проект по желанию.
# Сдавать ссылкой на Githab, Collab
# Данные можно выбрать на сайте kaggle.com или взять датасет, с которым работали на курсе. (Темы предложенные ниже для данного датасета)
# Варианты тем:
#  1) Проверить статистическую гипотезу о различии веса среди мужчин и женщин.
#     С помощью изученных функций на 5 вебинаре рассчитать нужный объем выборки для мощности теста 90%.
#     Выбрать критерий и обосновать его применение
#     Провести тест и интерпретировать результат.
#     Вывод представить в виде доверительного интервала в процентах для размера эффекта (см.конец 5 презентации)
#
#  2) Провести двухфакторный дисперсионный анализ. Проверить влияние на вес пола и приема алкоголя.
#     В рамках этой темы проверить условия применимости, провести анализ, интерпретировать результат.
#########################################################################################################################################
tinytex::install_tinytex()
#########################################################################################################################################
# 1. Загрузим необходимые библиотеки
#########################################################################################################################################
library(asbio)
library(BSDA)
library(dplyr)
library(effsize)
library(pwr)
library(rafalib)
library(rio)
library(car)

#########################################################################################################################################
# 2. EDA - Произведем разведочный анализ данных
#########################################################################################################################################
# Загрузим датасет 
ds.cardio <- import("cardio_train.csv")
head(ds.cardio)

# Посмотрим на структуру датасета
str(ds.cardio)

# Преобразуем возвраст в днях в возраст в годах
ds.cardio <- ds.cardio %>% mutate(age_years=(trunc(age/365)))
head(ds.cardio)

# Удалим колонки ID и Age так как они нам не понадобятся
ds.cardio <- ds.cardio[, -c(1, 2)]
head(ds.cardio)
dim(ds.cardio)

# Проверим есть ли некоректные данные по верхнему и нижнему давлению
err.data.qty = nrow(ds.cardio[ds.cardio$ap_hi < ds.cardio$ap_lo,])
# Если некоректные данные присутствуют то удалим их
if (err.data.qty > 0) {
  ds.cardio <- ds.cardio[ds.cardio$ap_hi > ds.cardio$ap_lo,]
  dim(ds.cardio)
}

# Создадим датасет который содержит в себе давление с нижней границей не менее 60 и 80 и с верхней границей не более 140 и 190
dsc.clean <- ds.cardio[ds.cardio$ap_hi > 80 & ds.cardio$ap_hi < 190,]
dsc.clean <- dsc.clean[dsc.clean$ap_lo > 60 & dsc.clean$ap_lo < 140,]
dim(dsc.clean)
sum(dsc.clean$ap_lo > 140)
sum(dsc.clean$ap_lo < 60)
sum(dsc.clean$ap_hi > 190)
sum(dsc.clean$ap_hi < 80)

# Посмотрим на среднее и стандартное отклонение для показателей давления
mean(dsc.clean$ap_lo)
sd(dsc.clean$ap_lo)
mean(dsc.clean$ap_hi)
sd(dsc.clean$ap_hi)

# Построим боксплот
mypar(1, 2)
boxplot(dsc.clean$ap_lo)
boxplot(dsc.clean$ap_hi)

# Построим гистограмму
mypar(1, 2)
hist(dsc.clean$ap_lo, main="Диастолическое давление", xlab = "ap_lo", ylab="Частота Наблюдений", breaks=10)
hist(dsc.clean$ap_hi, main="Систолическое давление", xlab = "ap_hi", ylab="", breaks=10)

# Проверим на близость к нормальному распределению показателей давления
mypar(1, 2)
qqnorm(dsc.clean$ap_lo, main="ap_lo")
qqline(dsc.clean$ap_lo, col="red", lwd=2)
abline(h=103, col="green")
qqnorm(dsc.clean$ap_hi, main="ap_hi")
qqline(dsc.clean$ap_hi, col="red", lwd=2)
# Теперь показатели давления близки к нормальному распределению и очевидно что в процессе измерений показатели округлялись
mypar(1, 2)
plot(density(dsc.clean$ap_lo, adjust = 10), col=1, xlim=c(30, 200), lwd=2, main="Распределение ap_lo/ap_hi")
abline(v=80.5, col="red")
lines(density(dsc.clean$ap_hi, adjust = 10), col=3, lwd=2, lty=2)
abline(v=123, col="red")
legend("topright",c("ap_lo","ap_hi"), col=c(1,3), lwd=c(1.5, 1.5), lty = c(1,2))

# Посмотрим на показатели веса
mypar(1, 1)
hist(dsc.clean$weight, main="Вес пациента", xlab = "weight", ylab="Частота Наблюдений")
boxplot(dsc.clean$weight)
# Построим боксплот разбив на группы: мужчины и женщины
boxplot(dsc.clean$weight ~ dsc.clean$gender, data=dsc.clean, 
        boxwex=0.7, at=1, 
        subset=dsc.clean$gender == "1", col="5", main="EDA",
        xlab="пол", ylab="вес",
        xlim=c(0.5, 2.5), ylim=c(0, 200))
boxplot(dsc.clean$weight ~ dsc.clean$gender, data=dsc.clean, add=TRUE,
        boxwex=0.7, at=2, 
        subset=dsc.clean$gender == "2", col="2")
legend("bottomleft", c("gender=1", "gender=2"), fill=c("5", "2"))
# Как и ожидалось вес женщин меньше чем вес мужчин

# Можно исключить из датасета вес более 150 и менее 20 так более высоки веса не сильно повлияют на анализ
dsc.clean <- dsc.clean[dsc.clean$weight > 20 & dsc.clean$weight < 150,]
dim(dsc.clean)

# Проверим на нормальность распределение веса
mypar(1, 1)
qqnorm(dsc.clean$weight, main="weight")
qqline(dsc.clean$weight, col="red", lwd=2)
abline(h=90, col="green")
# В целом показатели веса близки к нормальному распределению

# Посмотрим на наличие дисбаланса выборок мужчин и женщин
table(dsc.clean$gender)
# Дисбаланс присутствует
# Посмотрим нв дисбаланс в отнешении веса
table(dsc.clean$gender, dsc.clean$weight)
# Заметно что в подавляющем количестве случаев вес округлялся до целого
# Измерения с показателем веса с грамами округлим так как их очень мало
dsc.clean$weight <- round(dsc.clean$weight, digits=0)
table(dsc.clean$gender, dsc.clean$weight)

head(dsc.clean)

# Посмотрим на взаимную кореляцию веса и роста в зависимости от пола
mypar(1, 1)
plot(dsc.clean$weight, dsc.clean$height, pch=21,
     bg= as.numeric(factor(dsc.clean$gender)), xlab = "Вес", ylab= "Рост")
legend("topright", levels(factor(dsc.clean$gender)),col=seq(along=levels(factor(dsc.clean$gender))), pch=19,cex=1.6)

#########################################################################################################################################
# 3. #  Провериv статистическую гипотезу о различии веса среди мужчин и женщин.
#########################################################################################################################################
# 3.1 Убеждимся, что наблюдения независимы
# В наблюдении представлены пациенты разных возрастов от 29 до 64 лет
sort(unique(dsc.clean$age_years))
# В наблюдениях представлен широкий диапазон веса пациента от 21кг до 149кг
sort(unique(dsc.clean$weight))
# В наблюдениях представлены данные о весе как мужчин так и женщин, хотя наблюдается дисбаланс в сторону женщин
table(dsc.clean$gender)
# Вывод: Наблюдения не зависимы так как не имеют привязки к каким-то особым группам и условиям

# 3.2 Проверяем на нормальность данные с помощью qq  - графика
mypar(1, 1)
qqnorm(dsc.clean$weight)
qqline(dsc.clean$weight, col="red")
# Данные приближены к нормальному распределению

# 3.3 Установим гипотезу:
#     H0: нет статистически значимой разницы между весом мужчин и женщин - mu = mu0
#     H1: есть статистически значимая разница между весом мужчины и женщины - mu != mu0

# 3.4 Разобьем исходный датасет на две выборки по полу
weight.women <- dsc.clean[dsc.clean$gender==1, 3]
length(weight.women)
weight.men <- dsc.clean[dsc.clean$gender==2, 3]
length(weight.men)

# Исходя из данных у нас достаточно большой обем выборок и стандартное отклонение не известно.
# Следовательно используем t-кретерий.
# Предпологаем что выборки с разной дисперсией

# 3.5 Посчитаем статистику d Коэна
cohen.d(d=weight.men, weight.women)
# ES = 0.326303 то есть есть имеем слабый размер эффекта

# Зададим alpha
mu0.alpha <- 0.05
# Задаим мощность теста
mu0.power <- 0.9
# Задаим размер эффекта умеренной значимости
mu0.d <- 0.326303

# 3.6 Рассчитаем нужный объем выборки для мощности теста 90%.
pwr.t2n.test(n1=200, n2=200, d=mu0.d, sig.level=0.05, alternative="two.sided")$power
# Необходимый размер выборки для мощности теста в 90% -  по 200 наблюдений для каждой из групп


# 3.7 С помощью функции t.test, протестируем гипотезу
# Сформируем две случайные выборки по 200 наблюдений
set.seed(21)
w.w.200 <- sample(weight.women, 200)
w.w.200
w.m.200 <- sample(weight.men, 200)
w.m.200

t.test(w.m.200, w.w.200, alternative="two.sided")

# Выведем размер эффекта в %
print(mu0.d * 100)
# Выведем доверительный интервал ждя данного размера эффекта
ci <- t.test(w.m.200, w.w.200, alternative="two.sided")$conf.int
print((ci / mean(w.w.200)) * 100)

plot(mean(w.w.200),col=2, lwd=2, 
     xlim=c(0.5, 2.5), ylim=c(70,80),
     ylab="",
     main="")
interval=c(72.55,72.75)
lines(x=c(1,1), y=interval, col="red", lwd=3)
points(1.5, mean(w.m.200), col=3, lwd=2)
interval_1<-c(76.7,76.9)
lines(x=c(1.5,1.5), y=interval_1, col="blue", lwd=3)
legend("topleft",c("women","men"),fill=c("red","blue"))

#############
# 3.8 Выводы:
# Так как мы получили маленькую p-value то должны отвергнуть гипотезу H0.
# Но нужно учитывать что с увеличением выборки p-value будет уменьшаться.
# В целом мы можем считать что иметм слабый эффект различия между весом мужчин и женщин,
# но сомнительно что он будет иметь какое-то научное значение на уровне генеральной выборки всей популяции.

#########################################################################################################################################
# 4. Проведем двухфакторный дисперсионный анализ. Проверим влияние на вес, пола и приема алкоголя.
#########################################################################################################################################
# 4.1 Выведем средние арефметические веса по подгруппам пола
mypar(1, 1)
m1.g <- mean(dsc.clean[dsc.clean$gender==1, 3])
m2.g <- mean(dsc.clean[dsc.clean$gender==2, 3])
plot(dsc.clean$gender, dsc.clean$weight, cex=1, col=dsc.clean$gender,
     xlab="Пол", ylab="Вес", xlim=c(0.7, 2.5))
points(rep(0.8, 2), c(m1.g, m2.g), col=c(1, 2), lwd=2)
# Из рисунка видно что межгрупавая дисперсия не вилика

# Выведем средние арефметические веса по подгруппам неупотребления/потребления алкоголя
# Для удобства отображения создадим столбец alco2 в котором поменяем значения 0->1 и 1->2
dsc.clean$alco2 <- 0
dsc.clean$alco2[dsc.clean$alco == 0] <- 1
dsc.clean$alco2[dsc.clean$alco == 1] <- 2
m1.a <- mean(dsc.clean[dsc.clean$alco2==1, 3])
m2.a <- mean(dsc.clean[dsc.clean$alco2==2, 3])
plot(dsc.clean$alco2, dsc.clean$weight, cex=1, col=dsc.clean$alco2,
     xlab="Алкоголь", ylab="Вес", xlim=c(0.5, 2.5))
points(rep(0.8, 2), c(m1.a, m2.a), col=c(1, 2), lwd=2)
# Из рисунка видно что межгрупавая дисперсия также не велика

# 4.2 Проведем проверку на сбаласнсированность данных
table(dsc.clean$gender)
table(dsc.clean$alco2)
# Наблюдения в колонках gender и alco не сбалансированы
# Так как данный имеют дисбаланс, то дисперсионный анализ становится более
# чувствительным к нарушениям условий его применения. Нарушение
# условий ведет к росту вероятности ошибки первого рода

# 4.3 Что бы снизить вероятность ошибок первого рода создадим выборки
# с сбалансированным количеством наблюдений для gender и alco2 в количестве 200
set.seed(21)
w1.ga1 <- sample(dsc.clean$weight[dsc.clean$gender==1 & dsc.clean$alco2==1], 200)
w2.ga1 <- sample(dsc.clean$weight[dsc.clean$gender==1 & dsc.clean$alco2==2], 200)
w1.ga2 <- sample(dsc.clean$weight[dsc.clean$gender==2 & dsc.clean$alco2==1], 200)
w2.ga2 <- sample(dsc.clean$weight[dsc.clean$gender==2 & dsc.clean$alco2==2], 200)

w.united <- c(w1.ga1, w2.ga1, w1.ga2, w2.ga2)
alco.new <- c(rep(1, 200), rep(2, 200), rep(1, 200), rep(2, 200))
gender.new <- c(rep(1, 400), rep(2, 400))
# Создаем обьединенный датасет соблюдающий случайность и независимость
dsc.balanced <- data.frame(w.united, gender.new, alco.new)
dsc.balanced[190:210,]

# Получили сбалансированный датасет
table(dsc.balanced$gender.new, dsc.balanced$alco.new)

str(dsc.balanced)

# 4.4 Оценим однородность дисперсий
# Воспользуемся критерием Бартлетта
bartlett.test(list(w1.ga1, w2.ga1, w1.ga2, w2.ga2))

# Как видно условие нормальности соблюдаеться хорошо
# Принимаем нулевую гипотезу на уровне значимости 0.05 . 
# Статистически значимых различий между дисперсиями выборок нет (p-value > 0.05)

#Проверим предположение о нормальности распределений с помощью qq-графика
mypar(2, 2)
qqnorm(w1.ga1)
qqline(w1.ga1, col="red", lwd=2)
qqnorm(w2.ga1)
qqline(w2.ga1, col="red", lwd=2)
qqnorm(w1.ga2)
qqline(w1.ga2, col="red", lwd=2)
qqnorm(w2.ga2)
qqline(w2.ga2, col="red", lwd=2)
# Есть небольшие отклонения. Принимаем. 
# Тем более ,что у нас одинаковые объемы выборок

# 4.5 Выполняем дисперсионный анализ
# так как сбалансированные данные НЕ влияют на порядок включения факторов в модель
summary(aov(w.united ~ gender.new*alco.new, data=dsc.balanced))

# 4.6 Интерпретация результата
# Взаимодействие факторов «пол» и «употребление алкоголя» оказывают 
# низкий эффект на вес пациента на уровне значимости 0.05
# Фактор «пол» оказывает умеренное эффект а употребление алкоголя низкий эффект
# на вес пациента на уровне значимости 0.05
