import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';

void main() => runApp(const SpendSnapApp());

class Txn {
  final String id, title, category;
  final double amount;
  final DateTime date;
  final bool income;
  Txn({required this.id, required this.title, required this.category, required this.amount, required this.date, this.income=false});
  Map<String,dynamic> toJson()=>{'id':id,'title':title,'category':category,'amount':amount,'date':date.toIso8601String(),'income':income};
  factory Txn.fromJson(Map<String,dynamic> j)=>Txn(id:j['id'],title:j['title'],category:j['category'],amount:(j['amount'] as num).toDouble(),date:DateTime.parse(j['date']),income:j['income']??false);
}

class SpendSnapApp extends StatefulWidget {
  const SpendSnapApp({super.key});
  @override State<SpendSnapApp> createState()=>_SpendSnapAppState();
}
class _SpendSnapAppState extends State<SpendSnapApp> {
  ThemeMode mode=ThemeMode.system;
  @override Widget build(BuildContext context)=>MaterialApp(
    debugShowCheckedModeBanner:false, title:'SpendSnap', themeMode:mode,
    theme:ThemeData(colorSchemeSeed:const Color(0xFF5B5FEF), brightness:Brightness.light, useMaterial3:true),
    darkTheme:ThemeData(colorSchemeSeed:const Color(0xFF8B8FFF), brightness:Brightness.dark, useMaterial3:true),
    home: Home(onTheme:(v)=>setState(()=>mode=v)),
  );
}

class Home extends StatefulWidget {
  final ValueChanged<ThemeMode> onTheme;
  const Home({super.key, required this.onTheme});
  @override State<Home> createState()=>_HomeState();
}
class _HomeState extends State<Home> {
  int tab=0; List<Txn> txns=[]; double budget=20000;
  final fmt=NumberFormat.currency(locale:'en_IN',symbol:'₹',decimalDigits:0);
  @override void initState(){super.initState(); load();}
  Future<void> load() async {
    final p=await SharedPreferences.getInstance();
    final raw=p.getStringList('txns');
    setState(() {
      txns=raw?.map((x)=>Txn.fromJson(jsonDecode(x))).toList()??[
        Txn(id:'1',title:'Zomato',category:'Food',amount:249,date:DateTime.now().subtract(const Duration(hours:2))),
        Txn(id:'2',title:'Uber',category:'Transport',amount:180,date:DateTime.now().subtract(const Duration(days:1))),
        Txn(id:'3',title:'Amazon',category:'Shopping',amount:799,date:DateTime.now().subtract(const Duration(days:2))),
        Txn(id:'4',title:'Salary',category:'Income',amount:20000,date:DateTime.now(),income:true),
      ];
      budget=p.getDouble('budget')??20000;
    });
  }
  Future<void> save() async {
    final p=await SharedPreferences.getInstance();
    await p.setStringList('txns',txns.map((x)=>jsonEncode(x.toJson())).toList());
    await p.setDouble('budget',budget);
  }
  double get expenses=>txns.where((x)=>!x.income).fold(0,(a,b)=>a+b.amount);
  double get income=>txns.where((x)=>x.income).fold(0,(a,b)=>a+b.amount);
  Map<String,double> get cats {
    final m=<String,double>{};
    for(final t in txns.where((x)=>!x.income)) m[t.category]=(m[t.category]??0)+t.amount;
    return m;
  }
  void addTxn() async {
    final result=await showDialog<Txn>(context:context,builder:(_)=>const AddTxnDialog());
    if(result!=null){setState(()=>txns.insert(0,result)); await save();}
  }
  @override Widget build(BuildContext context){
    final pages=[
      Dashboard(txns:txns, budget:budget, expenses:expenses, income:income, cats:cats, fmt:fmt, onAdd:addTxn),
      TransactionsPage(txns:txns, fmt:fmt, onDelete:(t){setState(()=>txns.remove(t));save();}, onAdd:addTxn),
      AnalyticsPage(cats:cats, expenses:expenses, fmt:fmt),
      BudgetPage(budget:budget, expenses:expenses, fmt:fmt, onSave:(v){setState(()=>budget=v);save();}),
      SettingsPage(onTheme:widget.onTheme),
    ];
    return Scaffold(body:pages[tab], bottomNavigationBar:NavigationBar(selectedIndex:tab,onDestinationSelected:(i)=>setState(()=>tab=i),
      destinations:const [
        NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home),label:'Home'),
        NavigationDestination(icon:Icon(Icons.receipt_long_outlined),selectedIcon:Icon(Icons.receipt_long),label:'Transactions'),
        NavigationDestination(icon:Icon(Icons.pie_chart_outline),selectedIcon:Icon(Icons.pie_chart),label:'Analytics'),
        NavigationDestination(icon:Icon(Icons.account_balance_wallet_outlined),selectedIcon:Icon(Icons.account_balance_wallet),label:'Budget'),
        NavigationDestination(icon:Icon(Icons.person_outline),selectedIcon:Icon(Icons.person),label:'Profile'),
      ]));
  }
}

class Dashboard extends StatelessWidget {
  final List<Txn> txns; final double budget,expenses,income; final Map<String,double> cats; final NumberFormat fmt; final VoidCallback onAdd;
  const Dashboard({super.key,required this.txns,required this.budget,required this.expenses,required this.income,required this.cats,required this.fmt,required this.onAdd});
  @override Widget build(BuildContext context){
    final pct=(expenses/budget).clamp(0,1).toDouble();
    return SafeArea(child:CustomScrollView(slivers:[
      SliverPadding(padding:const EdgeInsets.fromLTRB(20,18,20,8),sliver:SliverToBoxAdapter(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
        Text('Good morning 👋',style:Theme.of(context).textTheme.titleMedium), Text('SpendSnap',style:Theme.of(context).textTheme.headlineLarge?.copyWith(fontWeight:FontWeight.bold)),
        const SizedBox(height:20),
        Card(child:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          const Text('This month'), const SizedBox(height:6), Text(fmt.format(expenses),style:Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.bold)),
          const SizedBox(height:14),LinearProgressIndicator(value:pct,minHeight:9,borderRadius:BorderRadius.circular(8)),
          const SizedBox(height:8),Text('${fmt.format((budget-expenses).clamp(0,budget))} remaining of ${fmt.format(budget)}')
        ]))),
        const SizedBox(height:12),
        Row(children:[
          Expanded(child:StatCard(label:'Income',value:fmt.format(income),icon:Icons.arrow_downward)),
          const SizedBox(width:10),Expanded(child:StatCard(label:'Expenses',value:fmt.format(expenses),icon:Icons.arrow_upward))
        ]),
        const SizedBox(height:20), Text('Where your money goes',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.bold)),
        const SizedBox(height:8),
        ...cats.entries.toList()..sort((a,b)=>b.value.compareTo(a.value))
      ].isEmpty?[]:[
        ...cats.entries.toList()..sort((a,b)=>b.value.compareTo(a.value))
      ].map((e)=>ListTile(contentPadding:EdgeInsets.zero,leading:CircleAvatar(child:Icon(categoryIcon(e.key))),title:Text(e.key),trailing:Text(fmt.format(e.value),style:const TextStyle(fontWeight:FontWeight.bold))))
      .toList()+[
        const SizedBox(height:12),Text('Recent transactions',style:Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.bold))
      ]))),
      SliverList(delegate:SliverChildBuilderDelegate((c,i){
        final t=txns.take(5).toList()[i];
        return ListTile(contentPadding:const EdgeInsets.symmetric(horizontal:20),leading:CircleAvatar(child:Icon(categoryIcon(t.category))),title:Text(t.title),subtitle:Text('${t.category} • ${DateFormat('dd MMM').format(t.date)}'),trailing:Text('${t.income?'+':'-'}${fmt.format(t.amount)}',style:TextStyle(fontWeight:FontWeight.bold,color:t.income?Colors.green:null)));
      },childCount:txns.take(5).length)),
    ]),floatingActionButton:FloatingActionButton.extended(onPressed:onAdd,icon:const Icon(Icons.add),label:const Text('Add')));
  }
}

class StatCard extends StatelessWidget { final String label,value; final IconData icon; const StatCard({super.key,required this.label,required this.value,required this.icon});
  @override Widget build(BuildContext c)=>Card(child:Padding(padding:const EdgeInsets.all(15),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Icon(icon),const SizedBox(height:8),Text(label),Text(value,style:Theme.of(c).textTheme.titleLarge?.copyWith(fontWeight:FontWeight.bold))])));
}

class TransactionsPage extends StatelessWidget {
  final List<Txn> txns; final NumberFormat fmt; final ValueChanged<Txn> onDelete; final VoidCallback onAdd;
  const TransactionsPage({super.key,required this.txns,required this.fmt,required this.onDelete,required this.onAdd});
  @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Transactions'),actions:[IconButton(onPressed:onAdd,icon:const Icon(Icons.add))]),body:ListView.builder(itemCount:txns.length,itemBuilder:(c,i){final t=txns[i];return Dismissible(key:ValueKey(t.id),onDismissed:(_)=>onDelete(t),background:Container(color:Colors.red,alignment:Alignment.centerRight,padding:const EdgeInsets.only(right:20),child:const Icon(Icons.delete,color:Colors.white)),child:ListTile(leading:CircleAvatar(child:Icon(categoryIcon(t.category))),title:Text(t.title),subtitle:Text('${t.category} • ${DateFormat('dd MMM yyyy').format(t.date)}'),trailing:Text('${t.income?'+':'-'}${fmt.format(t.amount)}',style:TextStyle(fontWeight:FontWeight.bold,color:t.income?Colors.green:null))));}));
}

class AnalyticsPage extends StatelessWidget {
  final Map<String,double> cats; final double expenses; final NumberFormat fmt;
  const AnalyticsPage({super.key,required this.cats,required this.expenses,required this.fmt});
  @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Analytics')),body:Padding(padding:const EdgeInsets.all(20),child:Column(children:[
    SizedBox(height:250,child:cats.isEmpty?const Center(child:Text('No expense data yet')):PieChart(PieChartData(sections:cats.entries.map((e)=>PieChartSectionData(value:e.value,title:'${(e.value/expenses*100).round()}%',radius:90)).toList()))),
    const SizedBox(height:20),Expanded(child:ListView(children:cats.entries.map((e)=>ListTile(title:Text(e.key),trailing:Text(fmt.format(e.value),style:const TextStyle(fontWeight:FontWeight.bold)))).toList()))
  ])));
}

class BudgetPage extends StatefulWidget {
  final double budget,expenses; final NumberFormat fmt; final ValueChanged<double> onSave;
  const BudgetPage({super.key,required this.budget,required this.expenses,required this.fmt,required this.onSave});
  @override State<BudgetPage> createState()=>_BudgetPageState();
}
class _BudgetPageState extends State<BudgetPage>{
  late TextEditingController ctl;
  @override void initState(){super.initState();ctl=TextEditingController(text:widget.budget.toStringAsFixed(0));}
  @override Widget build(BuildContext c){final remaining=(widget.budget-widget.expenses).clamp(0,widget.budget);return Scaffold(appBar:AppBar(title:const Text('Budget')),body:Padding(padding:const EdgeInsets.all(20),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Text('Monthly budget',style:Theme.of(c).textTheme.titleLarge),const SizedBox(height:10),
    TextField(controller:ctl,keyboardType:TextInputType.number,decoration:const InputDecoration(prefixText:'₹ ',border:OutlineInputBorder())),
    const SizedBox(height:16),FilledButton(onPressed:(){final v=double.tryParse(ctl.text);if(v!=null&&v>0)widget.onSave(v);ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content:Text('Budget saved')));},child:const Text('Save budget')),
    const SizedBox(height:30),Text('Remaining',style:Theme.of(c).textTheme.titleMedium),Text(widget.fmt.format(remaining),style:Theme.of(c).textTheme.headlineMedium?.copyWith(fontWeight:FontWeight.bold)),
    const SizedBox(height:10),LinearProgressIndicator(value:(widget.expenses/widget.budget).clamp(0,1).toDouble(),minHeight:10)
  ]))); }
}

class SettingsPage extends StatelessWidget {
  final ValueChanged<ThemeMode> onTheme; const SettingsPage({super.key,required this.onTheme});
  @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Profile & Settings')),body:ListView(children:[
    const UserAccountsDrawerHeader(accountName:Text('SpendSnap User'),accountEmail:Text('Personal budget'),currentAccountPicture:CircleAvatar(child:Icon(Icons.person))),
    ListTile(leading:const Icon(Icons.dark_mode),title:const Text('Dark mode'),trailing:Switch(value:Theme.of(c).brightness==Brightness.dark,onChanged:(v)=>onTheme(v?ThemeMode.dark:ThemeMode.light))),
    const ListTile(leading:Icon(Icons.lock_outline),title:Text('Privacy'),subtitle:Text('Your local transaction data stays on this device in this MVP.')),
    const ListTile(leading:Icon(Icons.info_outline),title:Text('About SpendSnap'),subtitle:Text('Smart spending, less effort.')),
  ]));
}

class AddTxnDialog extends StatefulWidget { const AddTxnDialog({super.key}); @override State<AddTxnDialog> createState()=>_AddTxnDialogState(); }
class _AddTxnDialogState extends State<AddTxnDialog>{
  final title=TextEditingController(),amount=TextEditingController(); String cat='Food'; bool income=false;
  final cats=['Food','Transport','Shopping','Entertainment','Education','Health','Bills','Other'];
  @override Widget build(BuildContext c)=>AlertDialog(title:Text(income?'Add income':'Add expense'),content:SingleChildScrollView(child:Column(children:[
    TextField(controller:title,decoration:const InputDecoration(labelText:'Merchant / title')),TextField(controller:amount,keyboardType:TextInputType.number,decoration:const InputDecoration(labelText:'Amount',prefixText:'₹ ')),
    DropdownButtonFormField<String>(value:cat,items:cats.map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(v)=>setState(()=>cat=v!),decoration:const InputDecoration(labelText:'Category')),
    SwitchListTile(title:const Text('This is income'),value:income,onChanged:(v)=>setState(()=>income=v))
  ])),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('Cancel')),FilledButton(onPressed:(){final a=double.tryParse(amount.text);if(title.text.trim().isEmpty||a==null||a<=0)return;Navigator.pop(c,Txn(id:DateTime.now().microsecondsSinceEpoch.toString(),title:title.text.trim(),category:income?'Income':cat,amount:a,date:DateTime.now(),income:income));},child:const Text('Add'))]);
}

IconData categoryIcon(String c)=>switch(c){'Food'=>Icons.restaurant,'Transport'=>Icons.directions_car,'Shopping'=>Icons.shopping_bag,'Entertainment'=>Icons.sports_esports,'Education'=>Icons.school,'Health'=>Icons.health_and_safety,'Bills'=>Icons.receipt_long,'Income'=>Icons.account_balance_wallet,_=>Icons.category};