interface NotifItem {
  item_name: string;
  amount: number;
  currency: string;
  billing_cycle: string;
  next_billing_date: string;
  trial_end_date: string | null;
}

function formatCurrency(amount: number, currency: string): string {
  return new Intl.NumberFormat("en-US", {
    style: "currency",
    currency,
  }).format(amount);
}

function daysBetween(from: Date, to: Date): number {
  const msPerDay = 86400000;
  const utcFrom = Date.UTC(from.getFullYear(), from.getMonth(), from.getDate());
  const utcTo = Date.UTC(to.getFullYear(), to.getMonth(), to.getDate());
  return Math.round((utcTo - utcFrom) / msPerDay);
}

export function formatRenewalMessage(item: NotifItem): string {
  const amount = formatCurrency(item.amount, item.currency);
  const days = daysBetween(new Date(), new Date(item.next_billing_date));

  if (days === 0) return `⚠️ *Upcoming Payment*: ${item.item_name} (${amount}) is due today!`;
  if (days === 1) return `📅 *Upcoming Payment*: ${item.item_name} (${amount}) is due tomorrow`;
  return `📅 *Upcoming Payment*: ${item.item_name} (${amount}) is due in ${days} days`;
}

export function formatTrialMessage(item: NotifItem): string {
  const amount = formatCurrency(item.amount, item.currency);
  const endDate = item.trial_end_date ?? item.next_billing_date;
  const days = daysBetween(new Date(), new Date(endDate));

  if (days === 0)
    return `⏰ *Trial Expiring*: ${item.item_name} trial expires today! Convert to paid (${amount}/${item.billing_cycle}) or cancel.`;
  if (days === 1)
    return `⏰ *Trial Expiring*: ${item.item_name} trial expires tomorrow. Full price: ${amount}/${item.billing_cycle}`;
  return `⏰ *Trial Expiring*: ${item.item_name} trial expires in ${days} days. Full price: ${amount}/${item.billing_cycle}`;
}

export function formatTestMessage(channel: string): string {
  return `✅ *SubTrkr Test Notification*\n\nYour ${channel} notifications are working! You'll receive reminders here for upcoming payments and expiring trials.`;
}
