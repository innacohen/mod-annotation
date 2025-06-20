#plt.title("Neither")
#shap.plots.beeswarm(shap_values[:,:,-1])

#plt.title("K Ca Channel")
#shap.plots.beeswarm(shap_values[:,:,5])

#plt.title("K Delayed Rectifier (1 gate)")
#shap.plots.beeswarm(shap_values[:,:,6])

#plt.title("K A-type (2 gates)")
#shap.plots.beeswarm(shap_values[:,:,4])

#=============GENERATE BARPLOTS==================================
#subtypes = df_train[df_train["new_subtype_label"] != "z_neither"]
# Sort the DataFrame by 'new_label' in alphabetical order
#subtypes = subtypes.sort_values(by='new_subtype_label')
# Create a count plot with different colors
#plt.figure(figsize=(8, 5))
#ax = sns.countplot(y='new_subtype_label', data=subtypes, order=subtypes['new_subtype_label'].unique())

# Ensure only whole numbers appear on the x-axis
#max_count = subtypes['new_subtype_label'].value_counts().max()  # Get max count for setting x-ticks
#ax.set_xticks(np.arange(0, max_count + 1, 1))  # Set integer x-ticks

# Add a title
#plt.title('Training Set')

# Show the plot
#plt.show()
#subtypes = df_test[df_test["new_subtype_label"] != "z_neither"]
# Sort the DataFrame by 'new_label' in alphabetical order
#subtypes = subtypes.sort_values(by='new_subtype_label')

# Create a count plot with different colors
#plt.figure(figsize=(8, 5))
#ax = sns.countplot(y='new_subtype_label', data=subtypes, order=subtypes['new_subtype_label'].unique())

# Ensure only whole numbers appear on the x-axis
#max_count = subtypes['new_subtype_label'].value_counts().max()  # Get max count for setting x-ticks
#ax.set_xticks(np.arange(0, max_count + 1, 1))  # Set integer x-ticks

# Add a title
#plt.title('Test Set')

# Show the plot
#plt.show()


#===============================COMMENTS=============================#

#row_id: 477 - commented out ranges included (https://modeldb.science/266818?tab=2&file=Ventricular_GUI.CircRes.ModelDB/Kss.mod)
#row_id: 481 - has comments with mod_state variables (https://modeldb.science/267511?tab=2&file=S1_Thal_NetPyNE_Frontiers_2022/sim/mod/ProbAMPANMDA_EMS.mod)
#row_id: 483 - has units in the mod_state ( https://modeldb.science/195666?tab=2&file=DewellGabbiani2018/mod_files/LGMD_KD_ca3.mod)
#row_id: 483 - was only extracting ONE parameter instead of multiple parameters (fixed)
#row_id 31 - has VALENCE in the write_ion (https://modeldb.science/116862?tab=2&file=b09jan13/IL3.mod)
#row_id 99 - need to fix use_ion
#todo: need to get INCLUDE for the notes table
#todo: should we collapse low-frequency labels
#todo: how do we process the SUFFIX, a lot of times the SUFFIX actually is the actual labeL?
#todo: do we include the name
#df["label"].value_counts()

#REsol;ved Questions
#Is it okay that we make assumptions like start after READ and stop after WRITE, what if there is no WRITE statement?
#How to capture variables that are commented out vs. not? (don't capture stuff commented out)
#what's the best way to capture 



#df_anno2["new_label"] = df_anno2["label"].map(map_new_label)

#df_train2.loc[df_train2["exclude_x86"]==1].index == df_train2.loc[df_train2["label"]=="exclude_old_architecture"].index
#df_train2["file_hash"].nunique()
#df_train3 = df_train2.loc[(df_train2["exclude_error"] != 1) & (df_train2["exclude_x86"] != 1)] 
#df_train3["file_hash"].nunique()
#All the "exclude" labels need to be collapsed to "neither"
#df_train4["label"].value_counts()
#df_train3[df_train3["type"]=="Exclude"].index
#subtype_counts = pd.DataFrame(df_train4["label"].value_counts()).reset_index()
#list(subtype_counts[subtype_counts['count']>=10]['label'])
#subtype_counts[subtype_counts["count"] >= 10].sort_values(by="label").reset_index(drop=True)
#subtype_counts["new_label"] = subtype_counts["label"].map(map_new_label)
#subtype_counts["new_label"].unique()
#subtype_counts.groupby(["new_label","label"]).count()
#df['broad_label'] = df["type"].map(map_broad_label)

# Extract features from url
#df["heading"] = df["url"].apply(get_heading)  # Extract heading from webpage
#df["citation"] = df["heading"].apply(get_citation)
#df["first_author"] = df["citation"].apply(get_author)
#df["year"] = df["citation"].apply(get_year)  # Now handles multiple years

#df["dir"] = df["url"].apply(get_dir)



#df["model_id"] = df["url"].apply(get_model_id)

#  Extract features from content
#df["title"] = df["content"].apply(get_title)
#df["comment"] = df["content"].apply(get_comment)
#df["use_ion"] = df["content"].apply(get_use_ion)
#Use empty list since cannot handle None
#df["range"] = df["content"].apply(get_range)
#df["global"] = df["content"].apply(get_global)

#Numeric Features
#df["tau_min"], df["tau_max"] = zip(*df["parameter"].apply(get_tau))
#df["e_min"], df["e_max"] = zip(*df["parameter"].apply(get_e))
