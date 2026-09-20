export const statuses = {
  beklemede: { label: 'Beklemede', color: '#D97706' },
  onaylandi: { label: 'Onaylandı', color: '#2563EB' },
  iptal: { label: 'İptal', color: '#9CA3AF' },
};

export const verticals = {
  villa: {
    key: 'villa',
    label: 'Villa',
    appTitle: 'Villa Takvim',
    customerLabel: 'Misafir',
    resourceLabel: 'Villa',
    resourcePlural: 'Villalar',
    addResourceLabel: 'Villa ekle',
    addLabel: 'Yeni rezervasyon',
    listLabel: 'Rezervasyonlar',
    emptyDay: 'Bu günde rezervasyon yok.',
    dateMode: 'range',
    timeEnabled: false,
    workStart: '15:00',
    workEnd: '11:00',
    slotMinutes: 60,
    primaryColor: '#0F766E',
    types: {
      konaklama: { label: 'Konaklama', color: '#0D9488' },
    },
    modules: ['calendar', 'reservations', 'resources'],
  },
  kuafor: {
    key: 'kuafor',
    label: 'Kuaför',
    appTitle: 'Kuaför Randevu',
    customerLabel: 'Müşteri',
    resourceLabel: 'Şube',
    resourcePlural: 'Şubeler',
    addResourceLabel: 'Şube ekle',
    addLabel: 'Yeni randevu',
    listLabel: 'Randevular',
    emptyDay: 'Bu günde randevu yok.',
    dateMode: 'single',
    timeEnabled: true,
    workStart: '09:00',
    workEnd: '19:00',
    slotMinutes: 30,
    primaryColor: '#BE185D',
    types: {
      randevu: { label: 'Randevu', color: '#BE185D', durationMin: 60 },
    },
    modules: ['calendar', 'reservations', 'resources'],
  },
};

export function getVertical(type) {
  const vertical = verticals[type];
  if (!vertical) {
    throw new Error('Geçersiz işletme tipi.');
  }
  return vertical;
}
