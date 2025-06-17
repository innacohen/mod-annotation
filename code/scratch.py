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
